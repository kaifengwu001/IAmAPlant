import SwiftUI
import SwiftData

enum DrawerSection: Int, CaseIterable, Identifiable {
    case yearOverview = -1
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
    @State private var topOverscroll: CGFloat = 0
    @State private var bottomOverscroll: CGFloat = 0

    @Query private var summaries: [DailySummary]

    private let collapsedHeight: CGFloat = 56

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
        snapStack
            .onChange(of: expandedDrawer) { _, newValue in
                let isYear = newValue == .yearOverview
                if showYearGrid != isYear {
                    showYearGrid = isYear
                }
            }
            .onChange(of: showYearGrid) { _, newValue in
                if newValue && expandedDrawer != .yearOverview {
                    snapTo(.yearOverview)
                } else if !newValue && expandedDrawer == .yearOverview {
                    snapTo(.daySummary)
                }
            }
    }

    // MARK: - Snap Stack

    private var snapStack: some View {
        GeometryReader { geo in
            let aboveCount = CGFloat(sectionsAbove.count)
            let belowCount = CGFloat(sectionsBelow.count)
            let expandedHeight = geo.size.height
                - (aboveCount + belowCount) * collapsedHeight

            VStack(spacing: 0) {
                ForEach(sectionsAbove) { section in
                    let isAdjacent = section == sectionsAbove.last
                    collapsedHeader(
                        for: section,
                        highlightProgress: isAdjacent
                            ? min(topOverscroll / 80, 1) : 0
                    )
                }

                expandedPanel(height: expandedHeight)

                ForEach(sectionsBelow) { section in
                    let isAdjacent = section == sectionsBelow.first
                    collapsedHeader(
                        for: section,
                        highlightProgress: isAdjacent
                            ? min(bottomOverscroll / 80, 1) : 0
                    )
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: expandedDrawer)
    }

    // MARK: - Collapsed Headers

    @ViewBuilder
    private func collapsedHeader(
        for section: DrawerSection,
        highlightProgress: CGFloat
    ) -> some View {
        if section == .yearOverview {
            yearCollapsedHeader(highlightProgress: highlightProgress)
                .frame(height: collapsedHeight)
                .contentShape(Rectangle())
                .onTapGesture { snapTo(section) }
                .simultaneousGesture(headerDragGesture(for: section))
        } else if section == .daySummary {
            DaySummaryView(
                scores: scores,
                selectedDate: selectedDate,
                isExpanded: false
            )
            .frame(height: collapsedHeight)
            .contentShape(Rectangle())
            .onTapGesture { snapTo(section) }
            .simultaneousGesture(headerDragGesture(for: section))
        } else {
            DrawerHeaderView(
                section: section,
                summaryText: summaryText(for: section),
                highlightProgress: highlightProgress,
                onTap: { snapTo(section) }
            )
            .frame(height: collapsedHeight)
            .simultaneousGesture(headerDragGesture(for: section))
        }
    }

    private func yearCollapsedHeader(highlightProgress: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24)

            Text(String(format: "%d", Calendar.current.component(.year, from: selectedDate)))
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .frame(height: collapsedHeight)
        .background(Color.white.opacity(0.04 + highlightProgress * 0.06))
    }

    // MARK: - Header Drag

    private func headerDragGesture(for section: DrawerSection) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                if abs(predicted) > 60 {
                    snapTo(section)
                }
            }
    }

    // MARK: - Expanded Panel

    private func expandedPanel(height: CGFloat) -> some View {
        EdgeAwareScrollView(
            panelID: expandedDrawer.rawValue,
            topOverscroll: $topOverscroll,
            bottomOverscroll: $bottomOverscroll,
            onTransition: handlePanelTransition,
            onHorizontalSwipe: handleDaySwipe
        ) {
            expandedContent
        }
        .frame(height: max(height, collapsedHeight))
        .clipped()
        .overlay(alignment: .top) {
            transitionHint(amount: topOverscroll, direction: .top)
        }
        .overlay(alignment: .bottom) {
            transitionHint(amount: bottomOverscroll, direction: .bottom)
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch expandedDrawer {
        case .yearOverview:
            YearGridView(selectedDate: $selectedDate, onDayTap: { date in
                selectedDate = date
                snapTo(.daySummary)
            })
        case .daySummary:
            DaySummaryView(
                scores: scores,
                selectedDate: selectedDate,
                isExpanded: true
            )
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

    // MARK: - Transition Hints

    @ViewBuilder
    private func transitionHint(
        amount: CGFloat,
        direction: VerticalEdge
    ) -> some View {
        if amount > 8 {
            let progress = min(amount / 80, 1.0)
            Image(
                systemName: direction == .top
                    ? "chevron.compact.up"
                    : "chevron.compact.down"
            )
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.15 + progress * 0.35))
            .scaleEffect(0.8 + progress * 0.3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Transition Handling

    private func handlePanelTransition(_ edge: VerticalEdge) {
        if edge == .top, let prev = expandedDrawer.previous {
            snapTo(prev)
        } else if edge == .bottom, let next = expandedDrawer.next {
            snapTo(next)
        }
    }

    private func handleDaySwipe(_ direction: Int) {
        advanceDay(by: direction)
    }

    // MARK: - Actions

    private func snapTo(_ section: DrawerSection) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            expandedDrawer = section
            topOverscroll = 0
            bottomOverscroll = 0
        }
    }

    private func advanceDay(by offset: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day, value: offset, to: selectedDate
        ) else { return }
        let today = DateBoundary.today()
        guard newDate <= today else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            selectedDate = newDate
        }
    }

    // MARK: - Summary Text

    private func summaryText(for section: DrawerSection) -> String {
        switch section {
        case .yearOverview:
            return String(format: "%d", Calendar.current.component(.year, from: selectedDate))
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
}
