import SwiftUI
import SwiftData

struct YearGridView: View {
    @Binding var selectedDate: Date
    let onDayTap: (Date) -> Void

    @Query private var summaries: [DailySummary]

    private let calendar = Calendar.current

    private var summaryLookup: [String: [Double]] {
        Dictionary(
            summaries.map { ($0.dateString, $0.scores) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        let layout = GridLayout(screenWidth: UIScreen.main.bounds.width)
        let cells = buildCells()

        VStack(spacing: 0) {
            Text(String(format: "%d", calendar.component(.year, from: selectedDate)))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.padding)
                .padding(.top, 16)
                .padding(.bottom, 8)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(layout.cellSize), spacing: layout.spacing), count: layout.columns),
                spacing: layout.spacing
            ) {
                ForEach(cells) { cell in
                    cellView(cell, layout: layout)
                }
            }
            .padding(.horizontal, layout.padding)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cellView(_ cell: YearCell, layout: GridLayout) -> some View {
        switch cell.cellType {
        case .monthLabel(let text):
            Text(text)
                .font(.system(size: max(layout.cellSize * 0.4, 7), weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: layout.cellSize, height: layout.cellSize)

        case .day(let date, let scores):
            let isToday = DateBoundary.dateString(from: date) == DateBoundary.dateString(from: DateBoundary.today())
            let isFuture = date > DateBoundary.today()

            Button { onDayTap(date) } label: {
                ZStack {
                    if let scores, !isFuture {
                        MiniRingView(scores: scores, size: layout.cellSize * 0.85)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(isFuture ? 0.04 : 0.12), lineWidth: 0.75)
                            .frame(width: layout.cellSize * 0.7, height: layout.cellSize * 0.7)
                    }

                    if isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                            .frame(width: layout.cellSize * 0.9, height: layout.cellSize * 0.9)
                    }
                }
                .frame(width: layout.cellSize, height: layout.cellSize)
            }
            .buttonStyle(.plain)

        case .empty:
            Color.clear
                .frame(width: layout.cellSize, height: layout.cellSize)
        }
    }

    // MARK: - Build Cells

    private func buildCells() -> [YearCell] {
        var result: [YearCell] = []
        let year = calendar.component(.year, from: selectedDate)

        for month in 1...12 {
            let monthName = calendar.shortMonthSymbols[month - 1].uppercased()
            result.append(YearCell(id: "m\(month)", cellType: .monthLabel(monthName)))

            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let range = calendar.range(of: .day, in: .month, for: monthStart) else {
                continue
            }

            for day in range {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                    continue
                }
                let dateStr = DateBoundary.dateString(from: date)
                let scores = summaryLookup[dateStr]
                result.append(YearCell(id: dateStr, cellType: .day(date, scores)))
            }
        }

        return result
    }
}

// MARK: - Layout Calculation

private struct GridLayout {
    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat
    let padding: CGFloat

    init(screenWidth: CGFloat) {
        self.columns = 14
        self.spacing = 2
        self.padding = 8
        let availWidth = screenWidth - padding * 2 - spacing * CGFloat(columns - 1)
        self.cellSize = floor(availWidth / CGFloat(columns))
    }
}

struct YearCell: Identifiable {
    let id: String
    let cellType: CellType

    enum CellType {
        case monthLabel(String)
        case day(Date, [Double]?)
        case empty
    }
}
