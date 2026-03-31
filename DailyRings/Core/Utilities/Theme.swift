import SwiftUI

enum Theme {
    // MARK: - Palette

    private static let moss = Color(red: 0.14, green: 0.24, blue: 0.00)

    // MARK: - Backgrounds & Surfaces

    static let background = Color(red: 0.95, green: 0.93, blue: 0.83) // Parchment
    static let surfacePrimary = moss.opacity(0.02)
    static let surfaceSecondary = moss.opacity(0.07)
    static let border = moss.opacity(0.15)

    // MARK: - Text

    static let textPrimary = moss
    static let textSecondary = moss.opacity(0.7)
    static let textTertiary = moss.opacity(0.4)
    static let textQuaternary = moss.opacity(0.2)

    // MARK: - Ring Colors

    static let sleep = Color(red: 0.42, green: 0.50, blue: 0.26) // Herb
    static let exercise = Color(red: 0.93, green: 0.48, blue: 0.07) // Radiate
    static let nutrition = Color(red: 0.96, green: 0.76, blue: 0.04) // Gold
    static let productivity = moss // Moss

    static let ringTrack = moss.opacity(0.08)
    static let accent = Color(red: 0.10, green: 0.28, blue: 0.11) // Forest

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
                        with: .color(textPrimary.opacity(brightness * opacity))
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
