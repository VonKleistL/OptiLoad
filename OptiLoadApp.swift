import SwiftUI

@main
struct OptiLoadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        MenuBarController.shared.setupMenuBar()
        
        // Initialize theme (removed applyTheme() call)
        _ = ThemeManager.shared
        
        // Start download server for browser extension
        DownloadServer.shared.start()
        
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop server on quit
        DownloadServer.shared.stop()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
