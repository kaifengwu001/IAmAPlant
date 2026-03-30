import SwiftUI
import SwiftData

@main
struct DailyRingsApp: App {
    @State private var supabaseService = SupabaseService()

    init() {
        NotificationDelegate.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(supabaseService)
        }
        .modelContainer(for: [
            DailySummary.self,
            PomodoroSession.self,
            SleepSession.self,
            UserSettings.self
        ])
    }
}
