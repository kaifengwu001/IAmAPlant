import SwiftUI

struct FeatureDrawerView: View {
    let section: DrawerSection
    let isExpanded: Bool
    let scores: [Double]
    let selectedDate: Date
    let onHeaderTap: () -> Void

    private var summaryText: String {
        switch section {
        case .sleep:
            let score = scores.count > 0 ? scores[0] : 0
            let hours = score * AppConstants.defaultSleepGoalHours
            return String(format: "%.1fh", hours)
        case .exercise:
            let score = scores.count > 1 ? scores[1] : 0
            let minutes = Int(score * Double(AppConstants.defaultExerciseGoalMinutes))
            return "\(minutes)m"
        case .nutrition:
            let score = scores.count > 2 ? scores[2] : 0
            return String(format: "%.1f/10", score * 10)
        case .productivity:
            let score = scores.count > 3 ? scores[3] : 0
            let minutes = Int(score * Double(AppConstants.defaultProductivityGoalMinutes))
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        case .daySummary:
            return ""
        case .yearOverview:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeaderView(
                section: section,
                summaryText: summaryText,
                onTap: onHeaderTap
            )

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch section {
        case .sleep:
            SleepDetailView(selectedDate: selectedDate)
                .frame(minHeight: UIScreen.main.bounds.height * 0.5)
        case .exercise:
            ExerciseDetailView(selectedDate: selectedDate)
                .frame(minHeight: UIScreen.main.bounds.height * 0.5)
        case .nutrition:
            NutritionView(selectedDate: selectedDate)
                .frame(minHeight: UIScreen.main.bounds.height * 0.5)
        case .productivity:
            ProductivityDetailView(selectedDate: selectedDate)
                .frame(minHeight: UIScreen.main.bounds.height * 0.5)
        case .daySummary:
            EmptyView()
        case .yearOverview:
            EmptyView()
        }
    }
}
