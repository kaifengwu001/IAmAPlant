import SwiftUI
import SwiftData

@main
struct DailyRingsApp: App {
    @State private var supabaseService = SupabaseService()
    @State private var isRestoringSession = true

    init() {
        NotificationDelegate.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRestoringSession {
                    launchScreen
                } else if supabaseService.isAuthenticated {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environment(supabaseService)
            .task { await restoreSession() }
        }
        .modelContainer(for: [
            DailySummary.self,
            PomodoroSession.self,
            SleepSession.self,
            UserSettings.self
        ])
    }

    private var launchScreen: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ProgressView()
                .tint(Theme.textTertiary)
        }
        .preferredColorScheme(.dark)
    }

    private func restoreSession() async {
        await supabaseService.restoreSession()
        isRestoringSession = false
    }
}
