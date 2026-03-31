import SwiftUI

struct RingView: View {
    let scores: [Double]
    let size: CGFloat
    let lineWidthRatio: CGFloat
    let gapRatio: CGFloat

    init(
        scores: [Double],
        size: CGFloat,
        lineWidthRatio: CGFloat = 0.08,
        gapRatio: CGFloat = 0.4
    ) {
        self.scores = scores
        self.size = size
        self.lineWidthRatio = lineWidthRatio
        self.gapRatio = gapRatio
    }

    private var lineWidth: CGFloat { size * lineWidthRatio }
    private var gap: CGFloat { lineWidth * gapRatio }

    var body: some View {
        ZStack {
            ForEach(Array(AppConstants.Ring.displayOrderOuterToInner.enumerated()), id: \.element) { index, ring in
                let ringRadius = radius(for: index)
                let score = score(for: ring)
                let color = Theme.ringColor(for: ring)

                Circle()
                    .stroke(Theme.ringTrack, lineWidth: lineWidth)
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

    private func score(for ring: AppConstants.Ring) -> Double {
        guard ring.scoreIndex < scores.count else { return 0 }
        return scores[ring.scoreIndex]
    }
}

struct MiniRingView: View {
    let scores: [Double]
    let size: CGFloat
    let lineWidthRatio: CGFloat
    let gapRatio: CGFloat

    init(
        scores: [Double],
        size: CGFloat = 24,
        lineWidthRatio: CGFloat = 0.10,
        gapRatio: CGFloat = 0.4
    ) {
        self.scores = scores
        self.size = size
        self.lineWidthRatio = lineWidthRatio
        self.gapRatio = gapRatio
    }

    var body: some View {
        RingView(
            scores: scores,
            size: size,
            lineWidthRatio: lineWidthRatio,
            gapRatio: gapRatio
        )
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
