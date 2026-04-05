import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var selectedDayOffset: Int? = 0
    @State private var currentSection: DrawerSection? = .daySummary
    @State private var showSettings = false
    @State private var pomodoroManager = PomodoroManager()

    private let syncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    private let dayRange = -365...0

    private var selectedDate: Date {
        Calendar.current.date(
            byAdding: .day, value: selectedDayOffset ?? 0, to: DateBoundary.today()
        ) ?? DateBoundary.today()
    }

    private var isToday: Bool {
        (selectedDayOffset ?? 0) == 0
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            horizontalDayPager
                .environment(pomodoroManager)
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            pomodoroManager.configure(modelContext: modelContext)
            syncCoordinator.configure(modelContext: modelContext)
            Task {
                await syncCoordinator.pullSettings()
                await syncCoordinator.pullRecent(days: 7)
                await syncCoordinator.pushPendingChanges()
            }
        }
        .onChange(of: selectedDayOffset) { _, _ in
            Task {
                await syncCoordinator.pullLatest(for: selectedDate)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                Task {
                    await pomodoroManager.onAppEnterBackground()
                    await syncCoordinator.pushPendingChanges()
                }
            case .active:
                Task {
                    await pomodoroManager.onAppReturnFromBackground()
                    await syncCoordinator.pullLatest(for: selectedDate)
                    await syncCoordinator.pushPendingChanges()
                }
            default:
                break
            }
        }
        .onReceive(syncTimer) { _ in
            if scenePhase == .active {
                Task {
                    await syncCoordinator.pushPendingChanges()
                }
            }
        }
    }

    // MARK: - Horizontal Day Pager

    private var horizontalDayPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(dayRange, id: \.self) { offset in
                    dayPage(offset: offset)
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedDayOffset)
    }

    private func dayPage(offset: Int) -> some View {
        let date = Calendar.current.date(
            byAdding: .day, value: offset, to: DateBoundary.today()
        ) ?? DateBoundary.today()
        let today = offset == 0

        return DayPageBinding(
            date: date,
            isToday: today,
            currentSection: $currentSection,
            onDayTap: { tappedDate in
                navigateToDay(tappedDate)
            },
            onSettingsTap: { showSettings = true }
        )
    }

    private func navigateToDay(_ date: Date) {
        let today = DateBoundary.today()
        let days = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
        let clamped = min(days, 0)
        withAnimation {
            selectedDayOffset = clamped
            currentSection = .daySummary
        }
    }

}

/// Bridges the non-Binding date into the VerticalSnapContainer's Binding<Date>.
private struct DayPageBinding: View {
    let date: Date
    let isToday: Bool
    @Binding var currentSection: DrawerSection?
    var onDayTap: ((Date) -> Void)?
    var onSettingsTap: (() -> Void)?

    @State private var localDate: Date

    init(
        date: Date,
        isToday: Bool,
        currentSection: Binding<DrawerSection?>,
        onDayTap: ((Date) -> Void)?,
        onSettingsTap: (() -> Void)? = nil
    ) {
        self.date = date
        self.isToday = isToday
        self._currentSection = currentSection
        self.onDayTap = onDayTap
        self.onSettingsTap = onSettingsTap
        self._localDate = State(initialValue: date)
    }

    var body: some View {
        VerticalSnapContainer(
            selectedDate: $localDate,
            currentSection: $currentSection,
            isToday: isToday,
            onDayTap: onDayTap,
            onSettingsTap: onSettingsTap
        )
        .onChange(of: date) { _, newDate in
            localDate = newDate
        }
    }
}
