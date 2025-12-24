import Foundation
import SwiftUI

@Observable
class Download: Identifiable {
    let id: UUID
    let url: URL
    var filename: String
    var filesize: Int64
    var downloadedBytes: Int64
    var status: DownloadStatus
    var speed: Double
    var chunks: [DownloadChunk]
    var destinationPath: String
    var errorMessage: String?
    var startedAt: Date?
    var completedAt: Date?
    
    init(url: URL, filename: String, filesize: Int64) {
        self.id = UUID()
        self.url = url
        self.filename = filename
        self.filesize = filesize
        self.downloadedBytes = 0
        self.status = .queued
        self.speed = 0
        self.chunks = []
        self.destinationPath = ""
        self.startedAt = Date()
    }
    
    var progress: Double {
        guard filesize > 0 else { return 0 }
        return Double(downloadedBytes) / Double(filesize)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: filesize, countStyle: .file)
    }
    
    var formattedDownloaded: String {
        ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
    }
    
    var formattedSpeed: String {
        guard speed > 0 else { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }
    
    var eta: String {
        guard speed > 0 else { return "Calculating..." }
        let remaining = Double(filesize - downloadedBytes)
        let seconds = remaining / speed
        
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

enum DownloadStatus: String {
    case queued = "Queued"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    
    var color: Color {
        switch self {
        case .queued: return .gray
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct DownloadChunk: Identifiable {
    let id: UUID
    var startByte: Int64
    var endByte: Int64
    var downloadedBytes: Int64
    var isComplete: Bool
}
