import SwiftUI

struct DaySummaryView: View {
    let scores: [Double]
    let selectedDate: Date
    let isExpanded: Bool

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: selectedDate)
    }

    private var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        if isExpanded {
            expandedView
        } else {
            collapsedBar
        }
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 4) {
                Text(dateLabel)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(weekdayLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }

            ZStack {
                RingView(scores: scores, size: 240)

                HStack {
                    edgeDayHint(systemImage: "chevron.left", firstLine: "prev", secondLine: "day", alignment: .leading)
                    Spacer()
                    edgeDayHint(systemImage: "chevron.right", firstLine: "next", secondLine: "day", alignment: .trailing)
                }
                .padding(.horizontal, -20)
            }

            ringLegend

            Spacer()

            gestureHints
        }
        .padding(.horizontal, 24)
    }

    private var ringLegend: some View {
        HStack(spacing: 20) {
            ForEach(AppConstants.Ring.displayOrderInnerToOuter, id: \.self) { ring in
                let score = score(for: ring)
                VStack(spacing: 4) {
                    Image(systemName: ring.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ringColor(for: ring))
                    Text("\(Int(score * 100))%")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var gestureHints: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textQuaternary)
            Text("details")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textQuaternary)
        }
        .padding(.bottom, 8)
    }

    private func edgeDayHint(
        systemImage: String,
        firstLine: String,
        secondLine: String,
        alignment: HorizontalAlignment
    ) -> some View {
        ZStack(alignment: systemImage == "chevron.left" ? .leading : .trailing) {
            VStack(alignment: alignment, spacing: 0) {
                Text(firstLine)
                Text(secondLine)
            }
            .font(.system(.caption2, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: systemImage == "chevron.left" ? .leading : .trailing)
            .padding(.leading, systemImage == "chevron.left" ? 14 : 0)
            .padding(.trailing, systemImage == "chevron.right" ? 14 : 0)

            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(Theme.textQuaternary)
        .frame(width: 56)
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack {
            Text(dateLabel)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            MiniRingView(
                scores: scores,
                size: 32,
                lineWidthRatio: 0.08,
                gapRatio: 0.25
            )
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Theme.surfacePrimary)
    }

    // MARK: - Helpers

    private func score(for ring: AppConstants.Ring) -> Double {
        guard ring.scoreIndex < scores.count else { return 0 }
        return scores[ring.scoreIndex]
    }
}
