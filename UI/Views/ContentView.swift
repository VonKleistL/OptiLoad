import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddDownload = false
    @State private var showSettings = false
    @State private var downloadURL = ""
    
    private var downloadManager = DownloadManager.shared
    private var appSettings = AppSettings.shared
    
    var body: some View {
        ZStack {
            // Glass blur background with opacity control
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(appSettings.windowOpacity)
                .ignoresSafeArea()
            
            // Background gradient overlay
            GlassTheme.primaryGradient
                .opacity(0.3)
                .ignoresSafeArea()
            
            // Animated background particles
            BackgroundParticles()
            
            VStack(spacing: 0) {
                // Header
                HeaderView(showAddDownload: $showAddDownload, showSettings: $showSettings)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Main content
                HStack(spacing: 20) {
                    // Left side - Downloads
                    VStack(spacing: 16) {
                        // Tabs - FULL WIDTH BUTTONS
                        TabSelector(selectedTab: $selectedTab)
                        
                        // Download list
                        ScrollView {
                            VStack(spacing: 12) {
                                let downloads = Array(downloadManager.activeDownloads.values)
                                
                                if selectedTab == 0 {
                                    // Downloading - ✅ FIXED: Include paused downloads
                                    ForEach(downloads.filter { $0.status == .downloading || $0.status == .paused }, id: \.id) { download in
                                        DownloadRow(download: download)
                                    }
                                } else if selectedTab == 1 {
                                    // Completed
                                    ForEach(downloads.filter { $0.status == .completed }, id: \.id) { download in
                                        DownloadRow(download: download)
                                    }
                                } else {
                                    // Queue
                                    ForEach(downloads.filter { $0.status == .queued }, id: \.id) { download in
                                        DownloadRow(download: download)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Right side - Stats
                    VStack(spacing: 16) {
                        SpeedGauge(speed: downloadManager.globalSpeed)
                            .padding(.top, 40)
                        
                        Spacer()
                        
                        // Queue info
                        QueueInfo()
                    }
                    .frame(width: 250)
                    .padding(.trailing, 20)
                }
                .padding(.top, 20)
            }
        }
        .frame(minWidth: 500, idealWidth: 800, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .sheet(isPresented: $showAddDownload) {
            AddDownloadSheet(downloadURL: $downloadURL, downloadManager: DownloadManager.shared)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct HeaderView: View {
    @Binding var showAddDownload: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
            
            Text("OptiLoad by VonKleist")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Toolbar buttons
            HStack(spacing: 12) {
                ToolbarButton(icon: "plus.circle.fill", action: { showAddDownload = true })
                ToolbarButton(icon: "gear", action: { showSettings = true })
            }
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

struct TabSelector: View {
    @Binding var selectedTab: Int
    let tabs = ["DOWNLOADING", "COMPLETED", "QUEUE"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    Text(tabs[index])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedTab == index ? .white : GlassTheme.textSecondary)
                        .frame(maxWidth: .infinity)  // FULL WIDTH
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if selectedTab == index {
                                    GlassTheme.accentGradient
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .contentShape(Rectangle())  // MAKES ENTIRE AREA CLICKABLE
                }
                .buttonStyle(.plain)  // REMOVES DEFAULT BUTTON PADDING
            }
        }
        .glassMorphic()
        .padding(.horizontal, 20)
    }
}

struct QueueInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUEUE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(GlassTheme.textTertiary)
            
            Text("EST. TIME SAVED: Measurable")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GlassTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassMorphic()
    }
}

struct BackgroundParticles: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: CGFloat.random(in: 50...150))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .blur(radius: 40)
            }
        }
        .ignoresSafeArea()
    }
}

// Glass blur effect
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
