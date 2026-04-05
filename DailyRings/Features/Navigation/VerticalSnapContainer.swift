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
    var onSettingsTap: (() -> Void)?

    @Query private var summaries: [DailySummary]

    private let headerHeight: CGFloat = 56
    @State private var outerPage: VerticalPage? = .accordion
    @State private var accordionTarget: DrawerSection? = .daySummary
    @State private var accordionOffset: CGFloat = 0
    @State private var dragStartAccordionOffset: CGFloat?
    @State private var accordionDragSourceSection: DrawerSection?
    @State private var accordionViewportHeight: CGFloat = UIScreen.main.bounds.height
    @State private var panelScrollLocked = false
    @State private var snapUnlockToken = 0
    @State private var suppressCurrentSectionSync = false
    @State private var suppressOuterPageSync = false
    // Keep year cold by default; only warm it briefly near the top.
    @State private var isYearPreloaded = false
    @State private var yearPreloadToken = 0
    @State private var pageTransitionOffset: CGFloat = 0

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

    private var shouldRenderYearPage: Bool {
        // Render year only when visible, transitioning, or intentionally preloaded.
        isYearPreloaded
            || outerPage == .year
            || currentSection == .yearOverview
            || pageTransitionOffset != 0
    }

    var body: some View {
        GeometryReader { geo in
            let pageOffset = accordionPageOffset(viewportHeight: geo.size.height)

            ZStack(alignment: .top) {
                // Keep year/day as two translated layers so the handoff tracks the finger.
                yearPage(viewportHeight: geo.size.height)
                    .offset(y: pageOffset - pageTravelDistance(viewportHeight: geo.size.height))
                    .compositingGroup()

                accordionPage(viewportHeight: geo.size.height)
                    .offset(y: pageOffset)
                    .compositingGroup()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .onAppear {
                accordionViewportHeight = geo.size.height
                syncFromCurrentSection(viewportHeight: geo.size.height, animated: false)
                updateYearPreloadState()
            }
            .onChange(of: geo.size.height) { _, newHeight in
                accordionViewportHeight = newHeight
            }
            .onChange(of: currentSection) { _, _ in
                if suppressCurrentSectionSync {
                    suppressCurrentSectionSync = false
                    updateYearPreloadState()
                    return
                }
                syncFromCurrentSection(viewportHeight: geo.size.height, animated: true)
                updateYearPreloadState()
            }
            .onChange(of: outerPage) { _, _ in
                updateYearPreloadState()
            }
            .onChange(of: panelScrollLocked) { _, _ in
                updateYearPreloadState()
            }
        }
    }

    // MARK: - Year Page (special)

    private func yearPage(viewportHeight: CGFloat) -> some View {
        let pageHeight = viewportHeight - headerHeight

        return VStack(spacing: 0) {
            if shouldRenderYearPage {
                sectionContent(.yearOverview, availableHeight: pageHeight)
            } else {
                Color.clear
            }

            Spacer(minLength: 0)
        }
        .frame(height: viewportHeight, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(yearPageDragGesture(viewportHeight: viewportHeight))
    }

    // MARK: - Accordion Page

    private func accordionPage(viewportHeight: CGFloat) -> some View {
        let metrics = accordionMetrics(viewportHeight: viewportHeight)

        return accordionVisibleLayer(viewportHeight: viewportHeight, metrics: metrics)
            .frame(height: viewportHeight)
            .clipped()
            .contentShape(Rectangle())
    }

    // MARK: - Accordion Layout

    private func accordionVisibleLayer(
        viewportHeight: CGFloat,
        metrics: AccordionMetrics
    ) -> some View {
        let interactiveSection = activeAccordionSection(viewportHeight: viewportHeight)

        return ZStack(alignment: .top) {
            ForEach(Array(nonYearSections.enumerated()), id: \.element.id) { index, section in
                let headerTop = headerY(for: index, metrics: metrics)
                let nextTop = nextHeaderY(after: index, metrics: metrics)
                let contentTop = headerTop + headerHeight
                let contentHeight = max(0, nextTop - contentTop)

                accordionContent(
                    for: section,
                    height: contentHeight,
                    top: contentTop,
                    expandedHeight: metrics.contentHeight,
                    isInteractive: section == interactiveSection
                )
                .allowsHitTesting(contentHeight > 1 && section == interactiveSection)
            }

            ForEach(Array(nonYearSections.enumerated()), id: \.element.id) { index, section in
                accordionHeader(for: section)
                    .offset(y: headerY(for: index, metrics: metrics))
                    .zIndex(3)
                    .simultaneousGesture(
                        accordionHeaderDragGesture(
                            from: interactiveSection,
                            metrics: metrics
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func accordionContent(
        for section: DrawerSection,
        height: CGFloat,
        top: CGFloat,
        expandedHeight: CGFloat,
        isInteractive: Bool
    ) -> some View {
        sectionContent(
            section,
            availableHeight: height,
            expandedHeight: expandedHeight,
            isInteractive: isInteractive
        )
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
            .frame(height: headerHeight)
            .background(Theme.surfacePrimary)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
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
                outerPage = .year
                cancelYearPreload(dismount: false)
                pageTransitionOffset = 0
            } else {
                outerPage = .accordion
                accordionTarget = resolvedSection
                accordionOffset = targetOffset
                pageTransitionOffset = 0
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
        snapHaptic()

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
            panelScrollLocked = true
            withAnimation(.easeOut(duration: 0.22)) {
                suppressCurrentSectionSync = true
                outerPage = .year
                cancelYearPreload(dismount: false)
                pageTransitionOffset = 0
                currentSection = .yearOverview
            } completion: {
                self.snapHaptic()
            }
            schedulePanelScrollUnlock()
            return
        }

        panelScrollLocked = true
        withAnimation(.easeOut(duration: 0.22)) {
            suppressCurrentSectionSync = true
            outerPage = .accordion
            accordionTarget = section
            accordionOffset = offset(for: section, viewportHeight: accordionViewportHeight)
            pageTransitionOffset = 0
            currentSection = section
        } completion: {
            self.snapHaptic()
        }
        schedulePanelScrollUnlock()
    }

    private func offset(
        for section: DrawerSection,
        viewportHeight: CGFloat? = nil
    ) -> CGFloat {
        guard let index = nonYearSections.firstIndex(of: section) else { return 0 }
        let metrics = accordionMetrics(viewportHeight: viewportHeight ?? UIScreen.main.bounds.height)
        return CGFloat(index) * metrics.contentHeight
    }

    private func accordionHeaderDragGesture(
        from section: DrawerSection,
        metrics: AccordionMetrics
    ) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                beginAccordionDrag(from: section)
                updateAccordionDrag(translationY: value.translation.height, metrics: metrics)
            }
            .onEnded { value in
                endAccordionDrag(
                    predictedTranslationY: value.predictedEndTranslation.height,
                    metrics: metrics
                )
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

    private func activeAccordionSection(viewportHeight: CGFloat) -> DrawerSection {
        accordionDragSourceSection
            ?? accordionTarget
            ?? nearestAccordionSection(viewportHeight: viewportHeight)
    }

    private func isPanelScrollEnabled(for section: DrawerSection) -> Bool {
        guard outerPage == .accordion else { return false }
        guard !panelScrollLocked else { return false }
        guard dragStartAccordionOffset == nil else { return false }
        return section == activeAccordionSection(viewportHeight: accordionViewportHeight)
    }

    private func handlePanelEdgePan(
        _ event: AccordionEdgePanEvent,
        from section: DrawerSection
    ) {
        let metrics = accordionMetrics(viewportHeight: accordionViewportHeight)

        switch event.phase {
        case .began:
            beginAccordionDrag(from: section)
            updateAccordionDrag(translationY: event.translationY, metrics: metrics)
        case .changed:
            updateAccordionDrag(translationY: event.translationY, metrics: metrics)
        case .ended, .cancelled:
            endAccordionDrag(
                predictedTranslationY: event.predictedEndTranslationY,
                metrics: metrics
            )
        }
    }

    private func beginAccordionDrag(from section: DrawerSection) {
        if dragStartAccordionOffset == nil {
            dragStartAccordionOffset = accordionOffset
            accordionDragSourceSection = section
            panelScrollLocked = true
        }
    }

    private func updateAccordionDrag(
        translationY: CGFloat,
        metrics: AccordionMetrics
    ) {
        let startOffset = dragStartAccordionOffset ?? accordionOffset

        if startOffset <= 1, translationY > 0 {
            cancelYearPreload(dismount: false)
            accordionOffset = 0
            pageTransitionOffset = rubberBandedPageOffset(
                translationY,
                travelDistance: pageTravelDistance(viewportHeight: metrics.viewportHeight)
            )
            return
        }

        cancelYearPreload()
        pageTransitionOffset = 0
        let proposedOffset = startOffset - translationY
        accordionOffset = rubberBandedOffset(proposedOffset, metrics: metrics)
    }

    private func endAccordionDrag(
        predictedTranslationY: CGFloat,
        metrics: AccordionMetrics
    ) {
        let startOffset = dragStartAccordionOffset ?? accordionOffset
        dragStartAccordionOffset = nil
        accordionDragSourceSection = nil

        if pageTransitionOffset > 0 {
            let travelDistance = pageTravelDistance(viewportHeight: metrics.viewportHeight)
            let projectedPageOffset = max(
                0,
                min(
                    travelDistance,
                    predictedTranslationY
                )
            )
            let shouldPageToYear = projectedPageOffset > headerHeight * 0.75 && startOffset <= 1

            if shouldPageToYear {
                withAnimation(.easeOut(duration: 0.22)) {
                    accordionOffset = 0
                    pageTransitionOffset = 0
                    suppressCurrentSectionSync = true
                    outerPage = .year
                    cancelYearPreload(dismount: false)
                    currentSection = .yearOverview
                } completion: {
                    self.snapHaptic()
                }
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    pageTransitionOffset = 0
                    outerPage = .accordion
                }
            }

            schedulePanelScrollUnlock()
            return
        }

        let projectedOffset = startOffset - predictedTranslationY
        let resolvedOffset = clampedAccordionOffset(projectedOffset, metrics: metrics)
        let snappedIndex = Int(round(resolvedOffset / metrics.contentHeight))
        let clampedIndex = min(max(snappedIndex, 0), nonYearSections.count - 1)
        let section = nonYearSections[clampedIndex]

        withAnimation(.easeOut(duration: 0.22)) {
            accordionOffset = CGFloat(clampedIndex) * metrics.contentHeight
            accordionTarget = section
            suppressCurrentSectionSync = true
            outerPage = .accordion
            pageTransitionOffset = 0
            currentSection = section
        } completion: {
            self.snapHaptic()
        }
        schedulePanelScrollUnlock()
    }

    private func accordionPageOffset(viewportHeight: CGFloat) -> CGFloat {
        let baseOffset: CGFloat = outerPage == .year
            ? pageTravelDistance(viewportHeight: viewportHeight)
            : 0
        return baseOffset + pageTransitionOffset
    }

    private func pageTravelDistance(viewportHeight: CGFloat) -> CGFloat {
        max(viewportHeight, 1)
    }

    private func rubberBandedPageOffset(
        _ offset: CGFloat,
        travelDistance: CGFloat
    ) -> CGFloat {
        if offset < 0 {
            return offset * 0.28
        }

        if offset > travelDistance {
            return travelDistance + (offset - travelDistance) * 0.28
        }

        return offset
    }

    private func yearPageDragGesture(viewportHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard outerPage == .year else { return }
                let translation = min(0, value.translation.height)
                pageTransitionOffset = max(
                    translation,
                    -pageTravelDistance(viewportHeight: viewportHeight)
                )
            }
            .onEnded { value in
                guard outerPage == .year else { return }
                let predictedTranslation = min(0, value.predictedEndTranslation.height)
                let shouldPageToAccordion = abs(predictedTranslation) > headerHeight * 0.75
                let fallback = accordionTarget ?? .daySummary

                if shouldPageToAccordion {
                    withAnimation(.easeOut(duration: 0.22)) {
                        suppressCurrentSectionSync = true
                        outerPage = .accordion
                        accordionTarget = fallback
                        accordionOffset = offset(for: fallback, viewportHeight: viewportHeight)
                        pageTransitionOffset = 0
                        currentSection = fallback
                    } completion: {
                        self.snapHaptic()
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.22)) {
                        pageTransitionOffset = 0
                    }
                }
            }
    }

    private func snapHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func shouldPreloadYearPage() -> Bool {
        guard outerPage == .accordion else { return false }
        guard !panelScrollLocked else { return false }
        guard dragStartAccordionOffset == nil else { return false }
        guard pageTransitionOffset == 0 else { return false }
        guard abs(accordionOffset) < 0.5 else { return false }

        let resolvedSection = accordionTarget ?? currentSection ?? .daySummary
        return resolvedSection == .daySummary
    }

    private func updateYearPreloadState() {
        guard shouldPreloadYearPage() else {
            cancelYearPreload()
            return
        }

        // Delay the mount so brief touches at the top do not wake the heavy year grid.
        let nextToken = yearPreloadToken + 1
        yearPreloadToken = nextToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard nextToken == yearPreloadToken else { return }
            guard shouldPreloadYearPage() else { return }
            isYearPreloaded = true
        }
    }

    private func cancelYearPreload(dismount: Bool = true) {
        yearPreloadToken += 1
        if dismount {
            isYearPreloaded = false
        }
    }

    private func schedulePanelScrollUnlock() {
        snapUnlockToken += 1
        let token = snapUnlockToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard token == snapUnlockToken else { return }
            panelScrollLocked = false
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(
        _ section: DrawerSection,
        availableHeight: CGFloat,
        expandedHeight: CGFloat? = nil,
        isInteractive: Bool = false
    ) -> some View {
        switch section {
        case .yearOverview:
            YearGridView(
                selectedDate: $selectedDate,
                availableHeight: availableHeight,
                onDayTap: { date in onDayTap?(date) },
                onSettingsTap: onSettingsTap
            )
        default:
            accordionPanelScrollView(
                section: section,
                availableHeight: availableHeight,
                expandedHeight: expandedHeight ?? availableHeight,
                isInteractive: isInteractive
            )
        }
    }

    private func accordionPanelScrollView(
        section: DrawerSection,
        availableHeight: CGFloat,
        expandedHeight: CGFloat,
        isInteractive: Bool
    ) -> some View {
        // Host each drawer once and only swap content when its identity actually changes.
        AccordionOwnedScrollView(
            contentID: panelContentID(for: section),
            isScrollEnabled: isPanelScrollEnabled(for: section),
            minContentHeight: expandedHeight,
            onEdgePan: { event in
                handlePanelEdgePan(event, from: section)
            }
        ) {
            panelBodyContent(for: section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: availableHeight, alignment: .top)
        .allowsHitTesting(isInteractive)
    }

    private func panelContentID(for section: DrawerSection) -> AccordionPanelContentID {
        let scoresHash = scores.reduce(into: Hasher()) { hasher, score in
            hasher.combine(score.bitPattern)
        }.finalize()

        return AccordionPanelContentID(
            section: section,
            dateString: DateBoundary.dateString(from: selectedDate),
            isToday: isToday,
            scoresHash: scoresHash
        )
    }

    @ViewBuilder
    private func panelBodyContent(for section: DrawerSection) -> some View {
        switch section {
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
        case .yearOverview:
            EmptyView()
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
            let average = ScoreCalculator.nutritionAverage(mealScores: currentSummary?.mealScores ?? [])
            return String(format: "%.1f/10", average)
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

private struct AccordionEdgePanEvent {
    enum Phase {
        case began
        case changed
        case ended
        case cancelled
    }

    let phase: Phase
    let translationY: CGFloat
    let predictedEndTranslationY: CGFloat
}

private struct AccordionPanelContentID: Hashable {
    let section: DrawerSection
    let dateString: String
    let isToday: Bool
    let scoresHash: Int
}

private struct AccordionOwnedScrollView<Content: View>: UIViewRepresentable {
    let contentID: AccordionPanelContentID
    let isScrollEnabled: Bool
    let minContentHeight: CGFloat
    let onEdgePan: (AccordionEdgePanEvent) -> Void
    let content: Content

    init(
        contentID: AccordionPanelContentID,
        isScrollEnabled: Bool,
        minContentHeight: CGFloat,
        onEdgePan: @escaping (AccordionEdgePanEvent) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.contentID = contentID
        self.isScrollEnabled = isScrollEnabled
        self.minContentHeight = minContentHeight
        self.onEdgePan = onEdgePan
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        context.coordinator.hostingController.sizingOptions = .intrinsicContentSize

        let hostedView = context.coordinator.hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostedView)

        let minHeightConstraint = hostedView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: context.coordinator.parent.minContentHeight
        )
        context.coordinator.minHeightConstraint = minHeightConstraint

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minHeightConstraint
        ])

        scrollView.panGestureRecognizer.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.minHeightConstraint?.constant = minContentHeight

        // Avoid replacing the hosted SwiftUI tree on every drag tick.
        if context.coordinator.contentID != contentID {
            context.coordinator.contentID = contentID
            context.coordinator.hostingController.rootView = AnyView(
                VStack(spacing: 0) {
                    content
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            )
        }

        if !context.coordinator.isEdgeHandoffActive {
            scrollView.isScrollEnabled = isScrollEnabled
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: AccordionOwnedScrollView
        let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
        var contentID: AccordionPanelContentID?
        var isEdgeHandoffActive = false
        var minHeightConstraint: NSLayoutConstraint?
        private var handoffLocksToTop = false

        init(parent: AccordionOwnedScrollView) {
            self.parent = parent
            self.contentID = parent.contentID
            self.hostingController.rootView = AnyView(
                VStack(spacing: 0) {
                    parent.content
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            )
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard isEdgeHandoffActive else { return }
            clamp(scrollView)
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }

            let translationY = recognizer.translation(in: scrollView).y
            let velocityY = recognizer.velocity(in: scrollView).y
            let predictedTranslationY = translationY + velocityY * 0.12
            let limits = offsetLimits(for: scrollView)
            let atTop = scrollView.contentOffset.y <= limits.top + 0.5
            let atBottom = scrollView.contentOffset.y >= limits.bottom - 0.5

            switch recognizer.state {
            case .began:
                isEdgeHandoffActive = false

            case .changed:
                if parent.isScrollEnabled && !isEdgeHandoffActive {
                    if atTop && translationY > 0 {
                        isEdgeHandoffActive = true
                        handoffLocksToTop = true
                        parent.onEdgePan(
                            AccordionEdgePanEvent(
                                phase: .began,
                                translationY: translationY,
                                predictedEndTranslationY: predictedTranslationY
                            )
                        )
                    } else if atBottom && translationY < 0 {
                        isEdgeHandoffActive = true
                        handoffLocksToTop = false
                        parent.onEdgePan(
                            AccordionEdgePanEvent(
                                phase: .began,
                                translationY: translationY,
                                predictedEndTranslationY: predictedTranslationY
                            )
                        )
                    }
                }

                if isEdgeHandoffActive {
                    clamp(scrollView)
                    parent.onEdgePan(
                        AccordionEdgePanEvent(
                            phase: .changed,
                            translationY: translationY,
                            predictedEndTranslationY: predictedTranslationY
                        )
                    )
                }

            case .ended:
                finishHandoffIfNeeded(
                    phase: .ended,
                    translationY: translationY,
                    predictedEndTranslationY: predictedTranslationY,
                    scrollView: scrollView
                )

            case .cancelled, .failed:
                finishHandoffIfNeeded(
                    phase: .cancelled,
                    translationY: translationY,
                    predictedEndTranslationY: predictedTranslationY,
                    scrollView: scrollView
                )

            default:
                break
            }
        }

        private func finishHandoffIfNeeded(
            phase: AccordionEdgePanEvent.Phase,
            translationY: CGFloat,
            predictedEndTranslationY: CGFloat,
            scrollView: UIScrollView
        ) {
            guard isEdgeHandoffActive else { return }

            clamp(scrollView)
            parent.onEdgePan(
                AccordionEdgePanEvent(
                    phase: phase,
                    translationY: translationY,
                    predictedEndTranslationY: predictedEndTranslationY
                )
            )
            isEdgeHandoffActive = false
            scrollView.isScrollEnabled = parent.isScrollEnabled
        }

        private func clamp(_ scrollView: UIScrollView) {
            let limits = offsetLimits(for: scrollView)
            scrollView.contentOffset.y = handoffLocksToTop ? limits.top : limits.bottom
        }

        private func offsetLimits(for scrollView: UIScrollView) -> (top: CGFloat, bottom: CGFloat) {
            let top = -scrollView.adjustedContentInset.top
            let bottom = max(
                top,
                scrollView.contentSize.height
                    - scrollView.bounds.height
                    + scrollView.adjustedContentInset.bottom
            )
            return (top, bottom)
        }
    }
}
