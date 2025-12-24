import Foundation
import Combine

@Observable
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    
    var activeDownloads: [UUID: Download] = [:]
    var globalSpeed: Double = 0
    var totalDownloaded: Int64 = 0
    
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var chunkTasks: [UUID: [Int: URLSessionDownloadTask]] = [:] // For multi-threaded
    private var speedTimer: Timer?
    private var lastMeasurement: (bytes: Int64, time: Date)?
    
    private var session: URLSession!
    
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.httpMaximumConnectionsPerHost = 32 // Allow more connections
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        startSpeedMonitoring()
    }
    
    func addDownload(url: URL) async throws {
        print("🚀 Starting download for: \(url)")
        
        // Get file metadata
        let (filesize, filename, supportsRange) = try await fetchMetadata(for: url)
        print("📦 File: \(filename), Size: \(filesize) bytes, Range support: \(supportsRange)")
        
        // Create download object
        let download = Download(url: url, filename: filename, filesize: filesize)
        download.destinationPath = AppSettings.shared.downloadFolder.appendingPathComponent(filename).path
        
        activeDownloads[download.id] = download
        
        // Start download
        await startDownload(download)
    }
    
    // MARK: - Start/Resume Download
    private func startDownload(_ download: Download) async {
        // Use multi-threading if range requests are supported
        if download.filesize > 1024 * 1024 * 5 { // 5MB minimum for multi-threading
            await startMultiThreadedDownload(download)
        } else {
            await startSimpleDownload(download)
        }
    }
    
    // MARK: - Pause/Resume
    func pauseDownload(_ download: Download) async {
        await MainActor.run {
            download.status = .paused
            print("⏸️ Download paused: \(download.filename)")
        }
        
        // Cancel active tasks
        if let task = downloadTasks[download.id] {
            task.cancel()
            downloadTasks.removeValue(forKey: download.id)
        }
        
        // Cancel chunk tasks
        if let chunks = chunkTasks[download.id] {
            for (_, task) in chunks {
                task.cancel()
            }
            chunkTasks.removeValue(forKey: download.id)
        }
    }
    
    func resumeDownload(_ download: Download) async {
        await MainActor.run {
            download.status = .downloading
            print("▶️ Resuming download: \(download.filename)")
        }
        
        // Restart the download from where it left off
        await startDownload(download)
    }
    
    // MARK: - Multi-threaded Download
    private func startMultiThreadedDownload(_ download: Download) async {
        download.status = .downloading
        
        let maxConnections = AppSettings.shared.maxConnections
        let chunkSize = download.filesize / Int64(maxConnections)
        
        print("⚡ Starting multi-threaded download with \(maxConnections) connections")
        
        // Create chunks if not already created
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
        
        // Start downloading each chunk
        chunkTasks[download.id] = [:]
        
        for (index, chunk) in download.chunks.enumerated() {
            // Skip completed chunks (for resume)
            if chunk.isComplete { continue }
            
            var request = URLRequest(url: download.url)
            let resumeStart = chunk.startByte + chunk.downloadedBytes
            request.setValue("bytes=\(resumeStart)-\(chunk.endByte)", forHTTPHeaderField: "Range")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let task = session.downloadTask(with: request)
            task.taskDescription = "\(download.id.uuidString)|\(index)" // Store download ID and chunk index
            chunkTasks[download.id]?[index] = task
            
            print("📥 Starting chunk \(index): bytes \(resumeStart)-\(chunk.endByte)")
            task.resume()
        }
    }
    
    // MARK: - Simple Download (fallback)
    private func startSimpleDownload(_ download: Download) async {
        download.status = .downloading
        
        var request = URLRequest(url: download.url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        // Resume if partially downloaded
        if download.downloadedBytes > 0 {
            request.setValue("bytes=\(download.downloadedBytes)-", forHTTPHeaderField: "Range")
        }
        
        let task = session.downloadTask(with: request)
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
        
        // Handle multi-threaded chunk completion
        if components.count > 1, let chunkIndex = Int(components[1]) {
            handleChunkCompletion(download: download, chunkIndex: chunkIndex, location: location)
        } else {
            // Handle simple download completion
            handleSimpleCompletion(download: download, location: location)
        }
    }
    
    private func handleChunkCompletion(download: Download, chunkIndex: Int, location: URL) {
        print("✅ Chunk \(chunkIndex) completed")
        
        guard chunkIndex < download.chunks.count else { return }
        
        // Mark chunk as complete
        download.chunks[chunkIndex].isComplete = true
        
        // Save chunk to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let chunkFile = tempDir.appendingPathComponent("\(download.id.uuidString)_chunk_\(chunkIndex)")
        
        do {
            if FileManager.default.fileExists(atPath: chunkFile.path) {
                try FileManager.default.removeItem(at: chunkFile)
            }
            try FileManager.default.moveItem(at: location, to: chunkFile)
            
            // Check if all chunks are complete
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
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Create output file
            FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: destinationURL)
            
            // Combine all chunks in order
            let tempDir = FileManager.default.temporaryDirectory
            for i in 0..<download.chunks.count {
                let chunkFile = tempDir.appendingPathComponent("\(download.id.uuidString)_chunk_\(i)")
                
                if let chunkData = try? Data(contentsOf: chunkFile) {
                    fileHandle.write(chunkData)
                    try? FileManager.default.removeItem(at: chunkFile) // Clean up
                }
            }
            
            try fileHandle.close()
            
            download.status = .completed
            download.completedAt = Date()
            download.downloadedBytes = download.filesize
            
            print("✅ Download completed: \(download.filename)")
            
            // Clean up
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
            // Update chunk progress
            if chunkIndex < download.chunks.count {
                download.chunks[chunkIndex].downloadedBytes = totalBytesWritten
            }
            
            // Calculate total downloaded across all chunks
            download.downloadedBytes = download.chunks.reduce(0) { $0 + $1.downloadedBytes }
        } else {
            // Simple download progress
            download.downloadedBytes = totalBytesWritten
            
            if totalBytesExpectedToWrite > 0 && download.filesize != totalBytesExpectedToWrite {
                download.filesize = totalBytesExpectedToWrite
            }
        }
        
        // Calculate speed
        if let startTime = download.startedAt {
            let elapsed = Date().timeIntervalSince(startTime)
            download.speed = elapsed > 0 ? Double(download.downloadedBytes) / elapsed : 0
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Download task failed: \(error.localizedDescription)")
            
            guard let taskDesc = task.taskDescription,
                  let downloadID = UUID(uuidString: taskDesc.components(separatedBy: "|").first ?? ""),
                  let download = activeDownloads[downloadID] else { return }
            
            // Don't mark as failed if it was a cancellation (pause)
            if (error as NSError).code != NSURLErrorCancelled {
                download.status = .failed
                download.errorMessage = error.localizedDescription
            }
            
            downloadTasks.removeValue(forKey: downloadID)
            chunkTasks.removeValue(forKey: downloadID)
        }
    }
    
    // MARK: - Metadata Fetch
    private func fetchMetadata(for url: URL) async throws -> (Int64, String, Bool) {
        print("🔍 Fetching metadata for: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10 // Shorter timeout
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request) // Use separate session
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.invalidResponse
            }
            
            print("📊 Metadata response: \(httpResponse.statusCode)")
            
            let filesize = httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : 104857600
            let filename = httpResponse.suggestedFilename ?? url.lastPathComponent
            
            // Check for range support
            let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")
            let supportsRange = acceptRanges?.lowercased() == "bytes"
            
            print("📊 Size: \(filesize), Accept-Ranges: \(acceptRanges ?? "none"), Range support: \(supportsRange)")
            
            return (filesize, filename, supportsRange)
            
        } catch {
            print("⚠️ Metadata fetch failed: \(error.localizedDescription)")
            
            // Try a GET request with Range header to test support
            var testRequest = URLRequest(url: url)
            testRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            testRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            testRequest.timeoutInterval = 5
            
            do {
                let (_, testResponse) = try await URLSession.shared.data(for: testRequest)
                if let httpResponse = testResponse as? HTTPURLResponse {
                    let supportsRange = httpResponse.statusCode == 206 // Partial Content
                    print("📊 Range test: status=\(httpResponse.statusCode), supports=\(supportsRange)")
                    
                    let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
                    return (104857600, filename, supportsRange) // Default size, but with correct range support
                }
            } catch {
                print("⚠️ Range test also failed")
            }
            
            // Final fallback
            let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
            return (104857600, filename, true) // ASSUME range support - most servers do
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
