import SwiftUI

struct RingView: View {
    let scores: [Double]
    let size: CGFloat
    let lineWidthRatio: CGFloat

    init(scores: [Double], size: CGFloat, lineWidthRatio: CGFloat = 0.08) {
        self.scores = scores
        self.size = size
        self.lineWidthRatio = lineWidthRatio
    }

    private var lineWidth: CGFloat { size * lineWidthRatio }
    private var gap: CGFloat { lineWidth * 0.4 }

    private static let ringColors: [Color] = [
        Color(red: 0.40, green: 0.55, blue: 0.90),  // Sleep — muted blue
        Color(red: 0.30, green: 0.85, blue: 0.55),  // Exercise — green
        Color(red: 0.95, green: 0.65, blue: 0.25),  // Nutrition — amber
        Color(red: 0.90, green: 0.35, blue: 0.40),  // Productivity — coral red
    ]

    private static let trackColor = Color.white.opacity(0.15)

    var body: some View {
        ZStack {
            ForEach(Array(AppConstants.Ring.allCases.enumerated()), id: \.element) { index, ring in
                let ringRadius = radius(for: index)
                let score = index < scores.count ? scores[index] : 0
                let color = Self.ringColors[index]

                Circle()
                    .stroke(Self.trackColor, lineWidth: lineWidth)
                    .frame(width: ringRadius * 2, height: ringRadius * 2)

                Circle()
                    .trim(from: 0, to: score)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    private func radius(for index: Int) -> CGFloat {
        let outerRadius = (size - lineWidth) / 2
        return outerRadius - CGFloat(index) * (lineWidth + gap)
    }
}

struct MiniRingView: View {
    let scores: [Double]
    let size: CGFloat

    init(scores: [Double], size: CGFloat = 24) {
        self.scores = scores
        self.size = size
    }

    var body: some View {
        RingView(scores: scores, size: size, lineWidthRatio: 0.10)
    }
}

#Preview("Large Ring") {
    RingView(scores: [0.9, 0.7, 0.5, 0.3], size: 240)
        .background(.black)
}

#Preview("Mini Ring") {
    MiniRingView(scores: [1.0, 0.8, 0.6, 0.4])
        .background(.black)
}
