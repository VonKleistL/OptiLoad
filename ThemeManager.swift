import SwiftUI
import Combine

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    var currentColorScheme: ColorScheme = .dark
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        updateTheme()
    }
    
    func updateTheme() {
        let settings = AppSettings.shared
        
        switch settings.theme {
        case .light:
            currentColorScheme = .light
        case .dark:
            currentColorScheme = .dark
        case .auto:  // FIXED: Changed from .system to .auto
            // Use system appearance
            if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
                currentColorScheme = appearance == .darkAqua ? .dark : .light
            } else {
                currentColorScheme = .dark
            }
        }
    }
}
