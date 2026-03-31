import SwiftUI

struct DrawerHeaderView: View {
    let section: DrawerSection
    let summaryText: String
    let onTap: () -> Void

    private var ring: AppConstants.Ring? {
        switch section {
        case .sleep: .sleep
        case .exercise: .exercise
        case .nutrition: .nutrition
        case .productivity: .productivity
        case .daySummary: nil
        case .yearOverview: nil
        }
    }

    private var color: Color {
        guard let ring else { return Theme.textPrimary }
        return Theme.ringColor(for: ring)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let ring {
                    Image(systemName: ring.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 24)
                }

                Text(ring?.label ?? "Summary")
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text(summaryText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(Theme.surfacePrimary)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
