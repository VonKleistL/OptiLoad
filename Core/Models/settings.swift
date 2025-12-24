import Foundation
import SwiftUI

@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // Appearance
    var theme: AppTheme = .auto
    var windowOpacity: Double = 0.85  // NEW: Transparency control
    
    // General
    var launchAtStartup: Bool = false
    var enableStandaloneWindows: Bool = false
    
    // Downloads
    var downloadFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    var autoRemoveDeleted: Bool = false
    var autoRemoveCompleted: Bool = false
    var autoRetryFailed: Bool = true
    var skipWebPages: Bool = true
    var useServerTime: Bool = true
    
    // Network
    var maxConnections: Int = 8
    var speedLimit: Int = 0
    var interceptBrowser: Bool = true
    var startWithoutConfirmation: Bool = false
    var proxyEnabled: Bool = false
    var proxyURL: String = ""
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case auto = "Auto"
    }
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Appearance
        if let themeRaw = UserDefaults.standard.string(forKey: "theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }
        
        let opacity = UserDefaults.standard.double(forKey: "windowOpacity")
        windowOpacity = opacity > 0 ? opacity : 0.85
        
        // General
        launchAtStartup = UserDefaults.standard.bool(forKey: "launchAtStartup")
        enableStandaloneWindows = UserDefaults.standard.bool(forKey: "enableStandaloneWindows")
        
        // Downloads
        if let folderPath = UserDefaults.standard.string(forKey: "downloadFolder"),
           let url = URL(string: folderPath) {
            downloadFolder = url
        }
        autoRemoveDeleted = UserDefaults.standard.bool(forKey: "autoRemoveDeleted")
        autoRemoveCompleted = UserDefaults.standard.bool(forKey: "autoRemoveCompleted")
        autoRetryFailed = UserDefaults.standard.bool(forKey: "autoRetryFailed")
        skipWebPages = UserDefaults.standard.bool(forKey: "skipWebPages")
        useServerTime = UserDefaults.standard.bool(forKey: "useServerTime")
        
        // Network
        let connections = UserDefaults.standard.integer(forKey: "maxConnections")
        maxConnections = connections > 0 ? connections : 8
        
        speedLimit = UserDefaults.standard.integer(forKey: "speedLimit")
        interceptBrowser = UserDefaults.standard.bool(forKey: "interceptBrowser")
        startWithoutConfirmation = UserDefaults.standard.bool(forKey: "startWithoutConfirmation")
        proxyEnabled = UserDefaults.standard.bool(forKey: "proxyEnabled")
        proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? ""
    }
    
    func saveSettings() {
        // Appearance
        UserDefaults.standard.set(theme.rawValue, forKey: "theme")
        UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity")
        
        // General
        UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup")
        UserDefaults.standard.set(enableStandaloneWindows, forKey: "enableStandaloneWindows")
        
        // Downloads
        UserDefaults.standard.set(downloadFolder.absoluteString, forKey: "downloadFolder")
        UserDefaults.standard.set(autoRemoveDeleted, forKey: "autoRemoveDeleted")
        UserDefaults.standard.set(autoRemoveCompleted, forKey: "autoRemoveCompleted")
        UserDefaults.standard.set(autoRetryFailed, forKey: "autoRetryFailed")
        UserDefaults.standard.set(skipWebPages, forKey: "skipWebPages")
        UserDefaults.standard.set(useServerTime, forKey: "useServerTime")
        
        // Network
        UserDefaults.standard.set(maxConnections, forKey: "maxConnections")
        UserDefaults.standard.set(speedLimit, forKey: "speedLimit")
        UserDefaults.standard.set(interceptBrowser, forKey: "interceptBrowser")
        UserDefaults.standard.set(startWithoutConfirmation, forKey: "startWithoutConfirmation")
        UserDefaults.standard.set(proxyEnabled, forKey: "proxyEnabled")
        UserDefaults.standard.set(proxyURL, forKey: "proxyURL")
    }
}
