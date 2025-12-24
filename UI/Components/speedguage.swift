import SwiftUI

struct SpeedGauge: View {
    let speed: Double // In bytes per second
    @State private var animatedProgress: Double = 0
    
    var formattedSpeed: String {
        formatSpeed(speed)
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(GlassTheme.glassBorder, lineWidth: 8)
            
            // Animated gradient ring
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.cyan,
                            Color.blue,
                            Color.purple,
                            Color.pink,
                            Color.cyan
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
            
            // Center content
            VStack(spacing: 4) {
                Text("GLOBAL SPEED")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(GlassTheme.textTertiary)
                
                Text(formattedSpeed)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(GlassTheme.textPrimary)
            }
        }
        .frame(width: 160, height: 160)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedProgress = min(speed / 10_000_000_000, 1.0) // Cap at 10GB/s
            }
        }
        .onChange(of: speed) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = min(newValue / 10_000_000_000, 1.0)
            }
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB/s", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB/s", mb)
        } else if kb >= 1 {
            return String(format: "%.0f KB/s", kb)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
}
