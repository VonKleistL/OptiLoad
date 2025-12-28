import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var settings = AppSettings.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            GlassTheme.primaryGradient
                .ignoresSafeArea()
            SettingsContent(selectedTab: $selectedTab, settings: settings, dismiss: dismiss)
        }
        .frame(width: 700, height: 600)
    }
}

struct SettingsContent: View {
    @Binding var selectedTab: Int
    let settings: AppSettings
    let dismiss: DismissAction
    let settingsTabs = ["General", "Downloads", "Network"]
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(dismiss: dismiss)
            SettingsTabBar(selectedTab: $selectedTab, tabs: settingsTabs)
            SettingsBody(selectedTab: selectedTab, settings: settings)
        }
    }
}

struct SettingsHeader: View {
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
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
    }
}

struct SettingsTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabButton(title: tab, isSelected: selectedTab == index) {
                    selectedTab = index
                }
            }
        }
        .glassMorphic()
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : GlassTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            GlassTheme.accentGradient
                        } else {
                            Color.clear
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsBody: View {
    let selectedTab: Int
    @Bindable var settings: AppSettings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if selectedTab == 0 {
                    GeneralSettingsContent(settings: settings)
                } else if selectedTab == 1 {
                    DownloadSettingsContent(settings: settings)
                } else {
                    NetworkSettingsContent(settings: settings)
                }
            }
            .padding(30)
        }
    }
}

// MARK: - General Settings
struct GeneralSettingsContent: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingToggle(title: "Launch at Startup", subtitle: "Start in menu bar", isOn: $settings.launchAtStartup)
            
            SettingRow(title: "Theme", subtitle: "Appearance") {
                Picker("", selection: $settings.theme) {
                    ForEach(AppSettings.AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            SettingRow(title: "Window Opacity", subtitle: "\(Int(settings.windowOpacity * 100))%") {
                Slider(value: $settings.windowOpacity, in: 0.0...1.0, step: 0.05)
                    .frame(width: 200)
            }
            
            SettingToggle(title: "Standalone Windows", subtitle: "Separate window per download", isOn: $settings.enableStandaloneWindows)
        }
        .onChange(of: settings.windowOpacity) { _, _ in
            settings.saveSettings()
        }
    }
}

// MARK: - Download Settings
// ✅ CHANGE: Replaced Stepper with TextField + arrow buttons for direct input
struct DownloadSettingsContent: View {
    @Bindable var settings: AppSettings
    @FocusState private var isConnectionFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingToggle(title: "Auto-remove Deleted Files", isOn: $settings.autoRemoveDeleted)
            SettingToggle(title: "Auto-remove Completed", isOn: $settings.autoRemoveCompleted)
            SettingToggle(title: "Auto-retry Failed", isOn: $settings.autoRetryFailed)
            SettingToggle(title: "Skip Web Pages", isOn: $settings.skipWebPages)
            SettingToggle(title: "Use Server Time", isOn: $settings.useServerTime)
            
            SettingRow(title: "Max Connections", subtitle: "Per download (1-128)") {
                HStack(spacing: 8) {
                    TextField("", value: $settings.maxConnections, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .focused($isConnectionFieldFocused)
                        .onChange(of: settings.maxConnections) { oldValue, newValue in
                            // Clamp value between 1 and 128
                            if newValue < 1 {
                                settings.maxConnections = 1
                            } else if newValue > 128 {
                                settings.maxConnections = 128
                            }
                            settings.saveSettings()
                        }
                    
                    VStack(spacing: 2) {
                        Button(action: {
                            if settings.maxConnections < 128 {
                                settings.maxConnections += 1
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 14)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if settings.maxConnections > 1 {
                                settings.maxConnections -= 1
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Network Settings
struct NetworkSettingsContent: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingToggle(title: "Browser Integration", subtitle: "Intercept downloads", isOn: $settings.interceptBrowser)
            SettingToggle(title: "Start Without Confirmation", isOn: $settings.startWithoutConfirmation)
            
            SettingRow(title: "Speed Limit", subtitle: "0 = unlimited (KB/s)") {
                TextField("", value: $settings.speedLimit, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
            
            SettingToggle(title: "Enable Proxy", isOn: $settings.proxyEnabled)
            
            if settings.proxyEnabled {
                SettingRow(title: "Proxy URL") {
                    TextField("http://proxy:8080", text: $settings.proxyURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
        }
    }
}

// MARK: - Reusable Components
struct SettingToggle: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(GlassTheme.textSecondary)
                }
            }
            Spacer()
            content
        }
        .padding(16)
        .glassMorphic()
    }
}
