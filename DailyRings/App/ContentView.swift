import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate: Date = DateBoundary.today()
    @State private var showSettings = false
    @State private var showYearGrid = false
    @State private var pomodoroManager = PomodoroManager()

    private var isToday: Bool {
        DateBoundary.dateString(from: selectedDate) == DateBoundary.dateString(from: DateBoundary.today())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VerticalSnapContainer(
                selectedDate: $selectedDate,
                showYearGrid: $showYearGrid,
                isToday: isToday
            )
            .environment(pomodoroManager)

            settingsButton
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            pomodoroManager.configure(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                Task { await pomodoroManager.onAppEnterBackground() }
            case .active:
                Task { await pomodoroManager.onAppReturnFromBackground() }
            default:
                break
            }
        }
    }

    private var settingsButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }
}
