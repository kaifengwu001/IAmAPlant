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
        guard let ring else { return .white }
        switch ring {
        case .sleep: return Color(red: 0.40, green: 0.55, blue: 0.90)
        case .exercise: return Color(red: 0.30, green: 0.85, blue: 0.55)
        case .nutrition: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .productivity: return Color(red: 0.90, green: 0.35, blue: 0.40)
        }
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
                    .foregroundStyle(.white)

                Spacer()

                Text(summaryText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(Color.white.opacity(0.04))
        }
        .buttonStyle(.plain)
    }
}
