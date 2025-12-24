import SwiftUI

struct DownloadRow: View {
    @Bindable var download: Download
    private var downloadManager = DownloadManager.shared
    
    // Explicit initializer to fix accessibility
    init(download: Download) {
        self.download = download
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: fileIcon(for: download.filename))
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GlassTheme.glassMedium)
                )
            
            // Download info
            VStack(alignment: .leading, spacing: 4) {
                Text(download.filename)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GlassTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundColor(GlassTheme.textSecondary)
                    
                    if download.status == .downloading {
                        // Mini waveform
                        WaveformMini()
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if download.status == .downloading || download.status == .paused {
                    Button(action: {
                        if download.status == .downloading {
                            Task {
                                await downloadManager.pauseDownload(download)
                            }
                        } else if download.status == .paused {
                            Task {
                                await downloadManager.resumeDownload(download)
                            }
                        }
                    }) {
                        Image(systemName: download.status == .downloading ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassMorphic()
    }
    
    private var statusText: String {
        switch download.status {
        case .downloading:
            return "\(formatBytes(download.downloadedBytes)) / \(formatBytes(download.filesize))"
        case .completed:
            return "Completed • \(formatBytes(download.filesize))"
        case .failed:
            return download.errorMessage ?? "Failed"
        case .paused:
            return "Paused • \(Int(download.progress * 100))%"
        case .queued:
            return "Queued"
        }
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "zip", "rar", "7z": return "doc.zipper"
        case "dmg", "pkg": return "externaldrive.fill"
        case "mp4", "mov", "avi": return "film"
        case "mp3", "wav", "flac": return "music.note"
        case "jpg", "png", "gif": return "photo"
        default: return "doc"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Mini waveform animation
struct WaveformMini: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan)
                    .frame(width: 3, height: animate ? CGFloat.random(in: 4...12) : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
