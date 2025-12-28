import Foundation
import Combine

@Observable
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    
    var activeDownloads: [UUID: Download] = [:]
    var globalSpeed: Double = 0
    var totalDownloaded: Int64 = 0
    
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var chunkTasks: [UUID: [Int: URLSessionDownloadTask]] = [:]
    private var downloadCookies: [UUID: String] = [:]
    private var downloadHeaders: [UUID: [String: String]] = [:]
    private var downloadResumeData: [UUID: Data] = [:]
    private var speedTimer: Timer?
    private var lastMeasurement: (bytes: Int64, time: Date)?
    
    private var session: URLSession!
    
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 7200
        config.httpMaximumConnectionsPerHost = 64
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.waitsForConnectivity = true
        config.urlCache = nil
        config.httpShouldUsePipelining = false
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        startSpeedMonitoring()
    }
    
    func addDownload(url: URL, cookies: String = "", headers: [String: String] = [:]) async throws {
        print("🚀 Starting download for: \(url)")
        
        let (filesize, filename, supportsRange) = try await fetchMetadata(for: url, cookies: cookies, headers: headers)
        print("📦 File: \(filename), Size: \(filesize) bytes, Range support: \(supportsRange)")
        
        let download = Download(url: url, filename: filename, filesize: filesize)
        download.destinationPath = AppSettings.shared.downloadFolder.appendingPathComponent(filename).path
        
        activeDownloads[download.id] = download
        
        if !cookies.isEmpty {
            downloadCookies[download.id] = cookies
        }
        if !headers.isEmpty {
            downloadHeaders[download.id] = headers
        }
        
        await startDownload(download)
    }
    
    // ✅ FIX: Force single-threaded for MediaFire to avoid 70MB cutoff
    private func startDownload(_ download: Download) async {
        let isMediaFire = download.url.host?.contains("mediafire.com") ?? false
        
        if isMediaFire {
            print("🔥 MediaFire detected - using single-threaded download")
            await startSimpleDownload(download)
        } else if download.filesize > 1024 * 1024 * 2 {
            await startMultiThreadedDownload(download)
        } else {
            await startSimpleDownload(download)
        }
    }
    
    // MARK: - Pause/Resume/Cancel
    func pauseDownload(_ download: Download) async {
        await MainActor.run {
            download.status = .paused
            print("⏸️ Download paused: \(download.filename)")
        }
        
        // For simple downloads: cancel with resume data
        if let task = downloadTasks[download.id] {
            task.cancel(byProducingResumeData: { [weak self] resumeData in
                if let data = resumeData {
                    print("💾 Saved resume data: \(data.count) bytes")
                    self?.downloadResumeData[download.id] = data
                }
            })
            downloadTasks.removeValue(forKey: download.id)
        }
        
        // For multi-threaded downloads: SUSPEND (don't cancel, don't remove from dictionary)
        if let chunks = chunkTasks[download.id] {
            for (_, task) in chunks {
                task.suspend()
            }
            print("⏸️ Suspended \(chunks.count) chunk tasks")
        }
    }
    
    func resumeDownload(_ download: Download) async {
        await MainActor.run {
            download.status = .downloading
            print("▶️ Resuming download: \(download.filename)")
        }
        
        // Check if we have suspended tasks (multi-threaded)
        if let chunks = chunkTasks[download.id], !chunks.isEmpty {
            // Resume suspended tasks
            for (_, task) in chunks {
                task.resume()
            }
            print("♻️ Resumed \(chunks.count) suspended chunk tasks")
        } else {
            // No suspended tasks, start fresh
            await startDownload(download)
        }
    }
    
    func cancelDownload(_ download: Download) async {
        await MainActor.run {
            print("❌ Download cancelled: \(download.filename)")
        }
        
        // Cancel simple download task
        if let task = downloadTasks[download.id] {
            task.cancel()
            downloadTasks.removeValue(forKey: download.id)
        }
        
        // Cancel multi-threaded chunk tasks
        if let chunks = chunkTasks[download.id] {
            for (_, task) in chunks {
                task.cancel()
            }
            chunkTasks.removeValue(forKey: download.id)
        }
        
        // Clean up temporary chunk files
        let tempDir = FileManager.default.temporaryDirectory
        for i in 0..<download.chunks.count {
            let chunkFile = tempDir.appendingPathComponent("\(download.id.uuidString)_chunk_\(i)")
            try? FileManager.default.removeItem(at: chunkFile)
        }
        
        // Clean up metadata
        downloadCookies.removeValue(forKey: download.id)
        downloadHeaders.removeValue(forKey: download.id)
        downloadResumeData.removeValue(forKey: download.id)
        
        // Remove from active downloads
        await MainActor.run {
            activeDownloads.removeValue(forKey: download.id)
        }
    }
    
    // MARK: - Multi-threaded Download
    private func startMultiThreadedDownload(_ download: Download) async {
        download.status = .downloading
        
        let maxConnections = AppSettings.shared.maxConnections
        let chunkSize = download.filesize / Int64(maxConnections)
        
        print("⚡ Starting multi-threaded download with \(maxConnections) connections")
        
        if download.chunks.isEmpty {
            var chunks: [DownloadChunk] = []
            for i in 0..<maxConnections {
                let startByte = Int64(i) * chunkSize
                let endByte = (i == maxConnections - 1) ? download.filesize - 1 : (startByte + chunkSize - 1)
                
                chunks.append(DownloadChunk(
                    id: UUID(),
                    startByte: startByte,
                    endByte: endByte,
                    downloadedBytes: 0,
                    isComplete: false
                ))
            }
            download.chunks = chunks
        }
        
        chunkTasks[download.id] = [:]
        
        for (index, chunk) in download.chunks.enumerated() {
            if chunk.isComplete { continue }
            
            var request = URLRequest(url: download.url)
            request.timeoutInterval = 300
            let resumeStart = chunk.startByte + chunk.downloadedBytes
            request.setValue("bytes=\(resumeStart)-\(chunk.endByte)", forHTTPHeaderField: "Range")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            
            if let cookies = downloadCookies[download.id] {
                request.setValue(cookies, forHTTPHeaderField: "Cookie")
            }
            
            if let headers = downloadHeaders[download.id] {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            let task = session.downloadTask(with: request)
            task.taskDescription = "\(download.id.uuidString)|\(index)"
            chunkTasks[download.id]?[index] = task
            
            print("📥 Starting chunk \(index): bytes \(resumeStart)-\(chunk.endByte)")
            task.resume()
        }
    }
    
    // MARK: - Simple Download (fallback)
    private func startSimpleDownload(_ download: Download) async {
        download.status = .downloading
        
        var request = URLRequest(url: download.url)
        request.timeoutInterval = 300
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        if let cookies = downloadCookies[download.id] {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        
        if let headers = downloadHeaders[download.id] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let task: URLSessionDownloadTask
        
        if let resumeData = downloadResumeData[download.id] {
            print("♻️ Resuming from saved data: \(resumeData.count) bytes")
            task = session.downloadTask(withResumeData: resumeData)
            downloadResumeData.removeValue(forKey: download.id)
        } else if download.downloadedBytes > 0 {
            request.setValue("bytes=\(download.downloadedBytes)-", forHTTPHeaderField: "Range")
            task = session.downloadTask(with: request)
        } else {
            task = session.downloadTask(with: request)
        }
        
        task.taskDescription = download.id.uuidString
        downloadTasks[download.id] = task
        
        print("⬇️ Starting simple download for: \(download.filename)")
        task.resume()
    }
    
    // MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskDesc = downloadTask.taskDescription else { return }
        
        let components = taskDesc.components(separatedBy: "|")
        guard let downloadIDString = components.first,
              let downloadID = UUID(uuidString: downloadIDString),
              let download = activeDownloads[downloadID] else {
            print("❌ Could not find download for task")
            return
        }
        
        if components.count > 1, let chunkIndex = Int(components[1]) {
            handleChunkCompletion(download: download, chunkIndex: chunkIndex, location: location)
        } else {
            handleSimpleCompletion(download: download, location: location)
        }
    }
    
    private func handleChunkCompletion(download: Download, chunkIndex: Int, location: URL) {
        print("✅ Chunk \(chunkIndex) completed")
        
        guard chunkIndex < download.chunks.count else { return }
        
        download.chunks[chunkIndex].isComplete = true
        
        let tempDir = FileManager.default.temporaryDirectory
        let chunkFile = tempDir.appendingPathComponent("\(download.id.uuidString)_chunk_\(chunkIndex)")
        
        do {
            if FileManager.default.fileExists(atPath: chunkFile.path) {
                try FileManager.default.removeItem(at: chunkFile)
            }
            try FileManager.default.moveItem(at: location, to: chunkFile)
            
            if download.chunks.allSatisfy({ $0.isComplete }) {
                print("🎉 All chunks complete, combining...")
                combineChunks(download: download)
            }
        } catch {
            print("❌ Error saving chunk: \(error)")
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }
    }
    
    private func combineChunks(download: Download) {
        let destinationURL = URL(fileURLWithPath: download.destinationPath)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: destinationURL)
            
            let tempDir = FileManager.default.temporaryDirectory
            
            for i in 0..<download.chunks.count {
                try autoreleasepool {
                    let chunkFile = tempDir.appendingPathComponent("\(download.id.uuidString)_chunk_\(i)")
                    
                    if let chunkData = try? Data(contentsOf: chunkFile) {
                        fileHandle.write(chunkData)
                        try? FileManager.default.removeItem(at: chunkFile)
                    }
                }
            }
            
            try fileHandle.close()
            
            download.status = .completed
            download.completedAt = Date()
            download.downloadedBytes = download.filesize
            
            print("✅ Download completed: \(download.filename)")
            
            downloadCookies.removeValue(forKey: download.id)
            downloadHeaders.removeValue(forKey: download.id)
            downloadResumeData.removeValue(forKey: download.id)
            chunkTasks.removeValue(forKey: download.id)
            
        } catch {
            print("❌ Error combining chunks: \(error)")
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }
    }
    
    private func handleSimpleCompletion(download: Download, location: URL) {
        let destinationURL = URL(fileURLWithPath: download.destinationPath)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            download.status = .completed
            download.completedAt = Date()
            download.downloadedBytes = download.filesize
            
            print("✅ Download completed: \(download.filename)")
            
            downloadCookies.removeValue(forKey: download.id)
            downloadHeaders.removeValue(forKey: download.id)
            downloadResumeData.removeValue(forKey: download.id)
            downloadTasks.removeValue(forKey: download.id)
            
        } catch {
            print("❌ Error moving file: \(error)")
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskDesc = downloadTask.taskDescription else { return }
        
        let components = taskDesc.components(separatedBy: "|")
        guard let downloadIDString = components.first,
              let downloadID = UUID(uuidString: downloadIDString),
              let download = activeDownloads[downloadID] else { return }
        
        if components.count > 1, let chunkIndex = Int(components[1]) {
            if chunkIndex < download.chunks.count {
                download.chunks[chunkIndex].downloadedBytes = totalBytesWritten
            }
            
            download.downloadedBytes = download.chunks.reduce(0) { $0 + $1.downloadedBytes }
        } else {
            download.downloadedBytes = totalBytesWritten
            
            if totalBytesExpectedToWrite > 0 && download.filesize != totalBytesExpectedToWrite {
                download.filesize = totalBytesExpectedToWrite
            }
        }
        
        if let startTime = download.startedAt {
            let elapsed = Date().timeIntervalSince(startTime)
            download.speed = elapsed > 0 ? Double(download.downloadedBytes) / elapsed : 0
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            guard let taskDesc = task.taskDescription,
                  let downloadID = UUID(uuidString: taskDesc.components(separatedBy: "|").first ?? ""),
                  let download = activeDownloads[downloadID] else { return }
            
            let nsError = error as NSError
            
            // Check if error is cancellation
            if nsError.code == NSURLErrorCancelled {
                // Only treat as failure if download is NOT paused
                if download.status != .paused {
                    print("⚠️ Download task cancelled unexpectedly: \(download.filename)")
                    download.status = .failed
                    download.errorMessage = "Download cancelled"
                } else {
                    // Expected cancellation due to pause - this is normal
                    print("✅ Task cancelled for pause (expected)")
                }
            } else {
                // Real error - not a cancellation
                print("❌ Download task failed: \(error.localizedDescription)")
                download.status = .failed
                download.errorMessage = error.localizedDescription
            }
            
            downloadTasks.removeValue(forKey: downloadID)
            // DON'T remove chunkTasks here if paused - they're suspended, not cancelled
            if download.status != .paused {
                chunkTasks.removeValue(forKey: downloadID)
            }
        }
    }
    
    // MARK: - Metadata Fetch
    private func fetchMetadata(for url: URL, cookies: String = "", headers: [String: String] = [:]) async throws -> (Int64, String, Bool) {
        print("🔍 Fetching metadata for: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        if !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.invalidResponse
            }
            
            print("📊 Metadata response: \(httpResponse.statusCode)")
            
            let filesize = httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : 104857600
            let filename = httpResponse.suggestedFilename ?? url.lastPathComponent
            
            let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")
            let supportsRange = acceptRanges?.lowercased() == "bytes"
            
            print("📊 Size: \(filesize), Accept-Ranges: \(acceptRanges ?? "none"), Range support: \(supportsRange)")
            
            return (filesize, filename, supportsRange)
            
        } catch {
            print("⚠️ Metadata fetch failed: \(error.localizedDescription)")
            
            var testRequest = URLRequest(url: url)
            testRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            testRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            testRequest.timeoutInterval = 5
            
            if !cookies.isEmpty {
                testRequest.setValue(cookies, forHTTPHeaderField: "Cookie")
            }
            
            do {
                let (_, testResponse) = try await URLSession.shared.data(for: testRequest)
                if let httpResponse = testResponse as? HTTPURLResponse {
                    let supportsRange = httpResponse.statusCode == 206
                    print("📊 Range test: status=\(httpResponse.statusCode), supports=\(supportsRange)")
                    
                    let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
                    return (104857600, filename, supportsRange)
                }
            } catch {
                print("⚠️ Range test also failed")
            }
            
            let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
            return (104857600, filename, true)
        }
    }
    
    private func startSpeedMonitoring() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateGlobalSpeed()
        }
    }
    
    private func updateGlobalSpeed() {
        let now = Date()
        let currentBytes = activeDownloads.values.reduce(0) { $0 + $1.downloadedBytes }
        
        if let last = lastMeasurement {
            let timeDiff = now.timeIntervalSince(last.time)
            let bytesDiff = currentBytes - last.bytes
            globalSpeed = Double(bytesDiff) / timeDiff
        }
        
        lastMeasurement = (currentBytes, now)
    }
    
    enum DownloadError: Error {
        case invalidResponse
        case rangeNotSupported
        case fileWriteError
    }
}
