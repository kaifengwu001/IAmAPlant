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
}

private enum VerticalPage: Int, Identifiable {
    case year
    case accordion

    var id: Int { rawValue }
}

struct VerticalSnapContainer: View {
    @Binding var selectedDate: Date
    @Binding var currentSection: DrawerSection?
    let isToday: Bool
    var onDayTap: ((Date) -> Void)?

    @Query private var summaries: [DailySummary]

    private let headerHeight: CGFloat = 56
    @State private var outerPage: VerticalPage? = .accordion
    @State private var accordionTarget: DrawerSection? = .daySummary
    @State private var accordionOffset: CGFloat = 0
    @State private var dragStartAccordionOffset: CGFloat?
    @State private var suppressCurrentSectionSync = false
    @State private var suppressOuterPageSync = false

    private var nonYearSections: [DrawerSection] {
        DrawerSection.allCases.filter { $0 != .yearOverview }
    }

    private var currentSummary: DailySummary? {
        let dateStr = DateBoundary.dateString(from: selectedDate)
        return summaries.first { $0.dateString == dateStr }
    }

    private var scores: [Double] {
        currentSummary?.scores ?? [0, 0, 0, 0]
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    yearPage(viewportHeight: geo.size.height)
                        .id(VerticalPage.year)

                    accordionPage(viewportHeight: geo.size.height)
                        .id(VerticalPage.accordion)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $outerPage)
            .onAppear {
                syncFromCurrentSection(viewportHeight: geo.size.height, animated: false)
            }
            .onChange(of: currentSection) { _, _ in
                if suppressCurrentSectionSync {
                    suppressCurrentSectionSync = false
                    return
                }
                syncFromCurrentSection(viewportHeight: geo.size.height, animated: true)
            }
            .onChange(of: outerPage) { _, newPage in
                if suppressOuterPageSync {
                    suppressOuterPageSync = false
                    return
                }
                handleOuterPageChange(newPage, viewportHeight: geo.size.height)
            }
        }
    }

    // MARK: - Year Page (special)

    private func yearPage(viewportHeight: CGFloat) -> some View {
        let pageHeight = viewportHeight - headerHeight

        return VStack(spacing: 0) {
            sectionContent(.yearOverview, availableHeight: pageHeight)
        }
        .frame(height: pageHeight)
        .clipped()
    }

    // MARK: - Accordion Page

    private func accordionPage(viewportHeight: CGFloat) -> some View {
        let metrics = accordionMetrics(viewportHeight: viewportHeight)

        return accordionVisibleLayer(viewportHeight: viewportHeight, metrics: metrics)
            .frame(height: viewportHeight)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(accordionDragGesture(metrics: metrics))
    }

    // MARK: - Accordion Layout

    private func accordionVisibleLayer(
        viewportHeight: CGFloat,
        metrics: AccordionMetrics
    ) -> some View {
        return ZStack(alignment: .top) {
            ForEach(Array(nonYearSections.enumerated()), id: \.element.id) { index, section in
                let headerTop = headerY(for: index, metrics: metrics)
                let nextTop = nextHeaderY(after: index, metrics: metrics)
                let contentTop = headerTop + headerHeight
                let contentHeight = max(0, nextTop - contentTop)

                accordionContent(
                    for: section,
                    height: contentHeight,
                    top: contentTop
                )
                .allowsHitTesting(contentHeight > 1)
            }

            ForEach(Array(nonYearSections.enumerated()), id: \.element.id) { index, section in
                accordionHeader(for: section)
                    .offset(y: headerY(for: index, metrics: metrics))
                    .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func accordionContent(
        for section: DrawerSection,
        height: CGFloat,
        top: CGFloat
    ) -> some View {
        sectionContent(section, availableHeight: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: height, alignment: .top)
            .mask(alignment: .top) {
                Rectangle()
                    .frame(maxWidth: .infinity)
                    .frame(height: height, alignment: .top)
            }
            .offset(y: top)
            .zIndex(1)
    }

    private func accordionHeader(for section: DrawerSection) -> some View {
        switch section {
        case .daySummary:
            return AnyView(daySummaryHeader(explicitDate: false))
        default:
            return AnyView(
                DrawerHeaderView(
                    section: section,
                    summaryText: summaryText(for: section),
                    onTap: { selectAccordionSection(section) }
                )
            )
        }
    }

    private func daySummaryHeader(explicitDate: Bool) -> some View {
        Button {
            selectAccordionSection(.daySummary)
        } label: {
            HStack {
                Text(formattedDate(explicitDate: explicitDate))
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                MiniRingView(scores: scores, size: 32)
            }
            .padding(.horizontal, 20)
            .frame(height: headerHeight)
            .background(Color.white.opacity(0.04))
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(explicitDate: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Accordion State

    private func accordionMetrics(viewportHeight: CGFloat) -> AccordionMetrics {
        AccordionMetrics(
            viewportHeight: viewportHeight,
            headerHeight: headerHeight,
            sectionCount: nonYearSections.count
        )
    }

    private func clampedAccordionOffset(
        _ offset: CGFloat,
        metrics: AccordionMetrics
    ) -> CGFloat {
        min(max(offset, 0), metrics.maxOffset)
    }

    private func headerY(
        for index: Int,
        metrics: AccordionMetrics
    ) -> CGFloat {
        guard index > 0 else { return CGFloat(index) * headerHeight }

        let offset = clampedAccordionOffset(accordionOffset, metrics: metrics)
        let startOffset = CGFloat(index - 1) * metrics.contentHeight
        let endOffset = CGFloat(index) * metrics.contentHeight
        let topY = CGFloat(index) * headerHeight
        let bottomY = metrics.viewportHeight
            - headerHeight * CGFloat(nonYearSections.count - index)

        if offset <= startOffset {
            return bottomY
        }

        if offset >= endOffset {
            return topY
        }

        let progress = (offset - startOffset) / metrics.contentHeight
        return bottomY + (topY - bottomY) * progress
    }

    private func nextHeaderY(
        after index: Int,
        metrics: AccordionMetrics
    ) -> CGFloat {
        guard index + 1 < nonYearSections.count else {
            return metrics.viewportHeight
        }

        return headerY(for: index + 1, metrics: metrics)
    }

    private func syncFromCurrentSection(
        viewportHeight: CGFloat,
        animated: Bool
    ) {
        let resolvedSection = currentSection ?? .daySummary
        let targetOuterPage: VerticalPage = resolvedSection == .yearOverview ? .year : .accordion
        let targetOffset = offset(for: resolvedSection, viewportHeight: viewportHeight)
        let isAlreadySynced =
            outerPage == targetOuterPage
            && (resolvedSection == .yearOverview
                || (accordionTarget == resolvedSection
                    && abs(accordionOffset - targetOffset) < 0.5))

        guard !isAlreadySynced else { return }

        let updates = {
            if resolvedSection == .yearOverview {
                suppressOuterPageSync = true
                outerPage = .year
            } else {
                suppressOuterPageSync = true
                outerPage = .accordion
                accordionTarget = resolvedSection
                accordionOffset = targetOffset
            }
        }

        if animated {
            withAnimation {
                updates()
            }
        } else {
            updates()
        }
    }

    private func handleOuterPageChange(
        _ newPage: VerticalPage?,
        viewportHeight: CGFloat
    ) {
        guard let newPage else { return }

        switch newPage {
        case .year:
            if currentSection != .yearOverview {
                suppressCurrentSectionSync = true
                currentSection = .yearOverview
            }
        case .accordion:
            let fallback = accordionTarget ?? nearestAccordionSection(viewportHeight: viewportHeight)
            accordionOffset = offset(for: fallback, viewportHeight: viewportHeight)
            if currentSection != fallback {
                suppressCurrentSectionSync = true
                currentSection = fallback
            }
        }
    }

    private func nearestAccordionSection(viewportHeight: CGFloat) -> DrawerSection {
        let metrics = accordionMetrics(viewportHeight: viewportHeight)
        let clampedOffset = clampedAccordionOffset(accordionOffset, metrics: metrics)
        let nearestIndex = Int(round(clampedOffset / metrics.contentHeight))
        let clampedIndex = min(max(nearestIndex, 0), max(nonYearSections.count - 1, 0))
        return nonYearSections[clampedIndex]
    }

    private func selectAccordionSection(_ section: DrawerSection) {
        guard section != .yearOverview else {
            withAnimation {
                suppressOuterPageSync = true
                suppressCurrentSectionSync = true
                outerPage = .year
                currentSection = .yearOverview
            }
            return
        }

        withAnimation {
            suppressOuterPageSync = true
            suppressCurrentSectionSync = true
            outerPage = .accordion
            accordionTarget = section
            accordionOffset = offset(for: section)
            currentSection = section
        }
    }

    private func offset(
        for section: DrawerSection,
        viewportHeight: CGFloat? = nil
    ) -> CGFloat {
        guard let index = nonYearSections.firstIndex(of: section) else { return 0 }
        let metrics = accordionMetrics(viewportHeight: viewportHeight ?? UIScreen.main.bounds.height)
        return CGFloat(index) * metrics.contentHeight
    }

    private func accordionDragGesture(metrics: AccordionMetrics) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if dragStartAccordionOffset == nil {
                    dragStartAccordionOffset = accordionOffset
                }

                let startOffset = dragStartAccordionOffset ?? accordionOffset
                let proposedOffset = startOffset - value.translation.height
                accordionOffset = rubberBandedOffset(proposedOffset, metrics: metrics)
            }
            .onEnded { value in
                let startOffset = dragStartAccordionOffset ?? accordionOffset
                dragStartAccordionOffset = nil

                let projectedOffset = startOffset - value.predictedEndTranslation.height
                let shouldPageToYear =
                    projectedOffset < -headerHeight * 0.75
                    && startOffset <= 1

                if shouldPageToYear {
                    withAnimation(.easeOut(duration: 0.22)) {
                        accordionOffset = 0
                        suppressOuterPageSync = true
                        suppressCurrentSectionSync = true
                        outerPage = .year
                        currentSection = .yearOverview
                    }
                    return
                }

                let resolvedOffset = clampedAccordionOffset(projectedOffset, metrics: metrics)
                let snappedIndex = Int(round(resolvedOffset / metrics.contentHeight))
                let clampedIndex = min(max(snappedIndex, 0), nonYearSections.count - 1)
                let section = nonYearSections[clampedIndex]

                withAnimation(.easeOut(duration: 0.22)) {
                    accordionOffset = CGFloat(clampedIndex) * metrics.contentHeight
                    accordionTarget = section
                    suppressOuterPageSync = true
                    suppressCurrentSectionSync = true
                    outerPage = .accordion
                    currentSection = section
                }
            }
    }

    private func rubberBandedOffset(
        _ offset: CGFloat,
        metrics: AccordionMetrics
    ) -> CGFloat {
        if offset < 0 {
            return offset * 0.28
        }

        if offset > metrics.maxOffset {
            return metrics.maxOffset + (offset - metrics.maxOffset) * 0.28
        }

        return offset
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(
        _ section: DrawerSection,
        availableHeight: CGFloat
    ) -> some View {
        switch section {
        case .yearOverview:
            YearGridView(
                selectedDate: $selectedDate,
                availableHeight: availableHeight,
                onDayTap: { date in onDayTap?(date) }
            )
        case .daySummary:
            DaySummaryView(
                scores: scores,
                selectedDate: selectedDate,
                isExpanded: true
            )
        case .sleep:
            ScrollView(.vertical, showsIndicators: false) {
                SleepDetailView(selectedDate: selectedDate, isToday: isToday)
            }
        case .exercise:
            ScrollView(.vertical, showsIndicators: false) {
                ExerciseDetailView(selectedDate: selectedDate)
            }
        case .nutrition:
            ScrollView(.vertical, showsIndicators: false) {
                NutritionView(selectedDate: selectedDate, isToday: isToday)
            }
        case .productivity:
            ScrollView(.vertical, showsIndicators: false) {
                ProductivityDetailView(selectedDate: selectedDate, isToday: isToday)
            }
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

private struct AccordionMetrics {
    let viewportHeight: CGFloat
    let headerHeight: CGFloat
    let sectionCount: Int

    var contentHeight: CGFloat {
        max(viewportHeight - CGFloat(sectionCount) * headerHeight, 1)
    }

    var maxOffset: CGFloat {
        CGFloat(max(sectionCount - 1, 0)) * contentHeight
    }
}
