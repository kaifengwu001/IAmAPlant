import SwiftUI
import SwiftData

struct YearGridView: View {
    @Binding var selectedDate: Date
    let availableHeight: CGFloat
    let onDayTap: (Date) -> Void

    @Query private var summaries: [DailySummary]

    private let calendar = Calendar.current
    private let titleHeight: CGFloat = 100

    private var summaryLookup: [String: [Double]] {
        Dictionary(
            summaries.map { ($0.dateString, $0.scores) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        let layout = GridLayout(
            screenWidth: UIScreen.main.bounds.width,
            availableHeight: availableHeight - titleHeight
        )
        let cells = buildCells()

        VStack(spacing: 0) {
            Text(String(format: "%d", calendar.component(.year, from: selectedDate)))
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.padding)
                .padding(.top, 24)
                .frame(height: titleHeight, alignment: .top)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(layout.cellSize), spacing: layout.horizontalSpacing),
                    count: layout.columns
                ),
                spacing: layout.verticalSpacing
            ) {
                ForEach(cells) { cell in
                    cellView(cell, layout: layout)
                }
            }
            .padding(.horizontal, layout.padding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func cellView(_ cell: YearCell, layout: GridLayout) -> some View {
        switch cell.cellType {
        case .monthLabel(let text):
            Text(text)
                .font(.system(
                    size: max(layout.cellSize * 0.4, 7),
                    weight: .bold,
                    design: .monospaced
                ))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: layout.cellSize, height: layout.cellSize)

        case .day(let date, let scores):
            let isToday = DateBoundary.dateString(from: date)
                == DateBoundary.dateString(from: DateBoundary.today())
            let isFuture = date > DateBoundary.today()

            Button { onDayTap(date) } label: {
                ZStack {
                    if isFuture {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.20),
                                lineWidth: 0.75
                            )
                            .frame(
                                width: layout.cellSize * 0.7,
                                height: layout.cellSize * 0.7
                            )
                    } else {
                        MiniRingView(scores: scores ?? [0, 0, 0, 0], size: layout.cellSize * 0.85)
                    }

                    if isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                            .frame(
                                width: layout.cellSize * 0.9,
                                height: layout.cellSize * 0.9
                            )
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

            guard let monthStart = calendar.date(
                from: DateComponents(year: year, month: month, day: 1)
            ),
                let range = calendar.range(of: .day, in: .month, for: monthStart)
            else {
                continue
            }

            for day in range {
                guard let date = calendar.date(
                    from: DateComponents(year: year, month: month, day: day)
                ) else { continue }
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
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let padding: CGFloat

    init(screenWidth: CGFloat, availableHeight: CGFloat) {
        let totalCells = 377

        var bestColumns = 14
        var bestCellSize: CGFloat = 10
        let sp: CGFloat = 2
        let pad: CGFloat = 8

        for cols in 12...20 {
            let rows = Int(ceil(Double(totalCells) / Double(cols)))
            let availWidth = screenWidth - pad * 2 - sp * CGFloat(cols - 1)
            let cellW = availWidth / CGFloat(cols)
            let totalHeight = CGFloat(rows) * (cellW + sp)
            let heightWithMargin = totalHeight + (cellW * 2)

            if heightWithMargin <= availableHeight && cellW > bestCellSize {
                bestColumns = cols
                bestCellSize = cellW
            }
        }

        self.columns = bestColumns
        self.horizontalSpacing = sp
        self.padding = pad
        
        let availWidth = screenWidth - padding * 2 - horizontalSpacing * CGFloat(columns - 1)
        self.cellSize = floor(availWidth / CGFloat(columns))
        
        let rows = Int(ceil(Double(totalCells) / Double(columns)))
        let requiredHeight = CGFloat(rows) * self.cellSize
        let bottomMargin = self.cellSize * 2
        let spaceToDistribute = availableHeight - requiredHeight - bottomMargin
        
        if rows > 1 && spaceToDistribute > 0 {
            self.verticalSpacing = max(sp, spaceToDistribute / CGFloat(rows - 1))
        } else {
            self.verticalSpacing = sp
        }
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
