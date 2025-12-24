import SwiftUI

struct GlassTheme {
    // Color palette matching your mockup
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.2, blue: 0.8),  // Purple
            Color(red: 0.2, green: 0.6, blue: 0.9)   // Blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.8, green: 0.2, blue: 0.6),  // Pink
            Color(red: 0.4, green: 0.2, blue: 0.8)   // Purple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Glass effect colors
    static let glassLight = Color.white.opacity(0.1)
    static let glassMedium = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.2)
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    
    // Status colors
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    static let downloading = Color.blue
}

// Glass modifier for consistent glassmorphism
struct GlassMorphic: ViewModifier {
    var cornerRadius: CGFloat = 16
    var blur: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GlassTheme.glassLight)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(GlassTheme.glassBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassMorphic(cornerRadius: CGFloat = 16, blur: CGFloat = 20) -> some View {
        modifier(GlassMorphic(cornerRadius: cornerRadius, blur: blur))
    }
}
