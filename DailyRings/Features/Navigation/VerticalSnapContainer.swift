import SwiftUI
import SwiftData

enum DrawerSection: Int, CaseIterable, Identifiable {
    case daySummary = 0
    case sleep = 1
    case exercise = 2
    case nutrition = 3
    case productivity = 4

    var id: Int { rawValue }

    var next: DrawerSection? {
        DrawerSection(rawValue: rawValue + 1)
    }

    var previous: DrawerSection? {
        DrawerSection(rawValue: rawValue - 1)
    }
}

struct VerticalSnapContainer: View {
    @Binding var selectedDate: Date
    @Binding var showYearGrid: Bool
    let isToday: Bool

    @State private var expandedDrawer: DrawerSection = .daySummary
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging = false

    @Query private var summaries: [DailySummary]

    private let collapsedHeight: CGFloat = 56
    private let snapThreshold: CGFloat = 60
    private let yearGridThreshold: CGFloat = 100

    private var currentSummary: DailySummary? {
        let dateStr = DateBoundary.dateString(from: selectedDate)
        return summaries.first { $0.dateString == dateStr }
    }

    private var scores: [Double] {
        currentSummary?.scores ?? [0, 0, 0, 0]
    }

    private var sectionsAbove: [DrawerSection] {
        DrawerSection.allCases.filter { $0.rawValue < expandedDrawer.rawValue }
    }

    private var sectionsBelow: [DrawerSection] {
        DrawerSection.allCases.filter { $0.rawValue > expandedDrawer.rawValue }
    }

    var body: some View {
        ZStack {
            if showYearGrid {
                yearGridLayer
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            } else {
                snapStack
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showYearGrid)
    }

    // MARK: - Snap Stack

    private var snapStack: some View {
        GeometryReader { geo in
            let aboveCount = CGFloat(sectionsAbove.count)
            let belowCount = CGFloat(sectionsBelow.count)
            let expandedHeight = geo.size.height - (aboveCount + belowCount) * collapsedHeight

            VStack(spacing: 0) {
                ForEach(sectionsAbove) { section in
                    collapsedHeader(for: section)
                }

                expandedContent(height: expandedHeight)
                    .frame(height: max(expandedHeight, collapsedHeight))
                    .clipped()

                ForEach(sectionsBelow) { section in
                    collapsedHeader(for: section)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: expandedDrawer)
    }

    // MARK: - Collapsed Headers

    @ViewBuilder
    private func collapsedHeader(for section: DrawerSection) -> some View {
        if section == .daySummary {
            DaySummaryView(scores: scores, selectedDate: selectedDate, isExpanded: false)
                .frame(height: collapsedHeight)
                .contentShape(Rectangle())
                .onTapGesture { snapTo(section) }
        } else {
            DrawerHeaderView(
                section: section,
                summaryText: summaryText(for: section),
                onTap: { snapTo(section) }
            )
            .frame(height: collapsedHeight)
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private func expandedContent(height: CGFloat) -> some View {
        ZStack {
            switch expandedDrawer {
            case .daySummary:
                DaySummaryView(scores: scores, selectedDate: selectedDate, isExpanded: true)
            case .sleep:
                SleepDetailView(selectedDate: selectedDate, isToday: isToday)
            case .exercise:
                ExerciseDetailView(selectedDate: selectedDate)
            case .nutrition:
                NutritionView(selectedDate: selectedDate, isToday: isToday)
            case .productivity:
                ProductivityDetailView(selectedDate: selectedDate, isToday: isToday)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(navigationDrag)
    }

    // MARK: - Navigation Drag

    private var navigationDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                isDragging = true
                dragTranslation = value.translation
            }
            .onEnded { value in
                isDragging = false
                let t = value.translation
                let predicted = value.predictedEndTranslation

                if isHorizontal(t) {
                    handleHorizontalEnd(t.width)
                } else {
                    let effectiveY = t.height + (predicted.height - t.height) * 0.2
                    handleVerticalEnd(effectiveY)
                }

                dragTranslation = .zero
            }
    }

    private func isHorizontal(_ t: CGSize) -> Bool {
        abs(t.width) > abs(t.height) * 1.3 && abs(t.width) > 30
    }

    private func handleVerticalEnd(_ effective: CGFloat) {
        if expandedDrawer == .daySummary && effective > yearGridThreshold {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showYearGrid = true
            }
            return
        }

        if effective < -snapThreshold, let next = expandedDrawer.next {
            snapTo(next)
        } else if effective > snapThreshold, let prev = expandedDrawer.previous {
            snapTo(prev)
        }
    }

    private func handleHorizontalEnd(_ width: CGFloat) {
        let threshold: CGFloat = 50
        if width > threshold {
            advanceDay(by: -1)
        } else if width < -threshold {
            advanceDay(by: 1)
        }
    }

    // MARK: - Actions

    private func snapTo(_ section: DrawerSection) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            expandedDrawer = section
        }
    }

    private func advanceDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        let today = DateBoundary.today()
        guard newDate <= today else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            selectedDate = newDate
        }
    }

    // MARK: - Summary Text

    private func summaryText(for section: DrawerSection) -> String {
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
        }
    }

    // MARK: - Year Grid

    private var yearGridLayer: some View {
        YearGridView(selectedDate: $selectedDate) { date in
            selectedDate = date
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showYearGrid = false
                expandedDrawer = .daySummary
            }
        }
    }
}
