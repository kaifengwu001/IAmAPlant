import SwiftUI

enum Theme {
    // MARK: - Colors

    static let background = Color.black
    static let surfacePrimary = Color.white.opacity(0.04)
    static let surfaceSecondary = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.1)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.4)
    static let textQuaternary = Color.white.opacity(0.2)

    static let sleep = Color(red: 0.40, green: 0.55, blue: 0.90)
    static let exercise = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let nutrition = Color(red: 0.95, green: 0.65, blue: 0.25)
    static let productivity = Color(red: 0.90, green: 0.35, blue: 0.40)

    static let ringTrack = Color.white.opacity(0.08)

    static func ringColor(for ring: AppConstants.Ring) -> Color {
        switch ring {
        case .sleep: sleep
        case .exercise: exercise
        case .nutrition: nutrition
        case .productivity: productivity
        }
    }

    // MARK: - Typography

    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }

    // MARK: - Grain Overlay (retro texture)

    struct GrainOverlay: View {
        let opacity: Double

        init(opacity: Double = 0.03) {
            self.opacity = opacity
        }

        var body: some View {
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height * 0.002) {
                    let x = Double.random(in: 0..<size.width)
                    let y = Double.random(in: 0..<size.height)
                    let brightness = Double.random(in: 0...1)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(brightness * opacity))
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - View Modifiers

struct RetroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surfacePrimary)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func retroCard() -> some View {
        modifier(RetroCardModifier())
    }
}
