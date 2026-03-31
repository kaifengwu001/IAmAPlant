import DeviceActivity
import SwiftUI

struct PomodoroUsageReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "pomodoro_usage")

    let content: (String) -> PomodoroReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> String {
        var totalDistractionSeconds = 0

        for await activityData in data {
            for await categoryActivity in activityData.activitySegments {
                totalDistractionSeconds += Int(categoryActivity.totalActivityDuration)
            }
        }

        return "\(totalDistractionSeconds)"
    }
}

struct PomodoroReportView: View {
    let distractionSeconds: String

    var body: some View {
        VStack(spacing: 8) {
            let seconds = Int(distractionSeconds) ?? 0
            let minutes = seconds / 60

            if minutes > 0 {
                Text("\(minutes)m distracted")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.exercise)
            } else {
                Text("Fully focused")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    init(_ seconds: String) {
        self.distractionSeconds = seconds
    }
}
