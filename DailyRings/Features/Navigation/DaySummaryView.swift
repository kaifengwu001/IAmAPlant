import SwiftUI

struct DaySummaryView: View {
    let scores: [Double]
    let selectedDate: Date
    let isExpanded: Bool

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: selectedDate)
        }
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
                    .foregroundStyle(.white)

                Text(weekdayLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            RingView(scores: scores, size: 240)

            ringLegend

            Spacer()

            pullHint
        }
        .padding(.horizontal, 24)
    }

    private var ringLegend: some View {
        HStack(spacing: 20) {
            ForEach(AppConstants.Ring.allCases, id: \.self) { ring in
                let score = ring.rawValue < scores.count ? scores[ring.rawValue] : 0
                VStack(spacing: 4) {
                    Image(systemName: ring.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(ringColor(for: ring))
                    Text("\(Int(score * 100))%")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var pullHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.2))
            Text("details")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack {
            Text(dateLabel)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            MiniRingView(scores: scores, size: 32)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Helpers

    private func ringColor(for ring: AppConstants.Ring) -> Color {
        switch ring {
        case .sleep: Color(red: 0.40, green: 0.55, blue: 0.90)
        case .exercise: Color(red: 0.30, green: 0.85, blue: 0.55)
        case .nutrition: Color(red: 0.95, green: 0.65, blue: 0.25)
        case .productivity: Color(red: 0.90, green: 0.35, blue: 0.40)
        }
    }
}
