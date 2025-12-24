import SwiftUI

struct AddDownloadSheet: View {
    @Binding var downloadURL: String
    let downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss
    @State private var isDownloading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            GlassTheme.primaryGradient
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Add Download")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Download URL")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GlassTheme.textSecondary)
                    
                    TextField("https://example.com/file.zip", text: $downloadURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(GlassTheme.glassMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(GlassTheme.glassBorder, lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 30)
                
                // Download info preview
                if !downloadURL.isEmpty, let url = URL(string: downloadURL) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.cyan)
                            Text("Valid URL detected")
                                .font(.system(size: 12))
                                .foregroundColor(GlassTheme.textSecondary)
                        }
                        
                        Text(url.lastPathComponent)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassMorphic()
                    .padding(.horizontal, 30)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GlassTheme.glassMedium)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: startDownload) {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Start Download")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(downloadURL.isEmpty || isDownloading ?
                                  AnyShapeStyle(Color.gray.opacity(0.3)) :
                                  AnyShapeStyle(GlassTheme.accentGradient))
                    )
                    .buttonStyle(.plain)
                    .disabled(downloadURL.isEmpty || isDownloading)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 500, height: 450)
    }
    
    private func startDownload() {
        guard let url = URL(string: downloadURL.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Invalid URL"
            return
        }
        
        print("🎯 Starting download from AddDownloadSheet for: \(url)")
        isDownloading = true
        errorMessage = nil
        
        Task {
            do {
                try await downloadManager.addDownload(url: url)
                print("✅ Download task created successfully")
                await MainActor.run {
                    dismiss()
                    downloadURL = ""
                    isDownloading = false
                }
            } catch {
                print("❌ Download failed with error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }
}
