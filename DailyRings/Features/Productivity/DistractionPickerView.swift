import SwiftUI
import FamilyControls

struct DistractionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()

    private static let storageKey = "pomodoroActivitySelection"

    private var selectionCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select apps that count as distractions during Pomodoro sessions.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)

            if selectionCount > 0 {
                Text("\(selectionCount) selected")
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 16)
            }

            FamilyActivityPicker(selection: $selection)
                .onChange(of: selection) { _, newValue in
                    Self.persist(newValue)
                }
        }
        .navigationTitle("Distracting Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    Self.persist(selection)
                    dismiss()
                }
                .font(.system(.body, design: .monospaced, weight: .medium))
            }
        }
        .onAppear {
            if let saved = Self.loadSelection() {
                selection = saved
            }
        }
    }

    // MARK: - Persistence (standard UserDefaults — only main app needs this)

    private static func persist(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return selection
    }

    static var hasSelection: Bool {
        guard let selection = loadSelection() else { return false }
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }
}
