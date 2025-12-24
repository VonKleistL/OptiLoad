import SwiftUI
import AppKit

class MenuBarController: NSObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var popoverWindow: NSWindow?
    
    func setupMenuBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "OptiLoad")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        // Create a window instead of popover for resizing
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OptiLoad"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.minSize = NSSize(width: 400, height: 300)
        window.maxSize = NSSize(width: 2000, height: 2000)
        popoverWindow = window
    }
    
    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }
    
    @objc func toggleWindow() {
        if let window = popoverWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                // Position near menu bar icon
                if let button = statusItem?.button {
                    let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
                    let windowRect = window.frame
                    let x = buttonRect.midX - windowRect.width / 2
                    let y = buttonRect.minY - windowRect.height - 5
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc func showMenu() {
        let menu = NSMenu()
        
        // Add Download
        let addItem = NSMenuItem(title: "Add Download", action: #selector(showWindow), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Show Window
        let showItem = NSMenuItem(title: "Show OptiLoad", action: #selector(toggleWindow), keyEquivalent: "o")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(title: "About OptiLoad", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit OptiLoad", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc func showWindow() {
        toggleWindow()
    }
    
    @objc func openSettings() {
        // TODO: Open settings window
        print("Settings clicked")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "OptiLoad"
        alert.informativeText = "Version 1.0\n\nA powerful download manager for macOS\nby VonKleist"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
