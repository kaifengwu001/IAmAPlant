import SwiftUI
import SwiftData

struct YearGridView: View {
    @Binding var selectedDate: Date
    let availableHeight: CGFloat
    let onDayTap: (Date) -> Void
    var onSettingsTap: (() -> Void)?

    @Query private var summaries: [DailySummary]

    private let calendar = Calendar.current
    private let titleHeight: CGFloat = 100
    @State private var cachedCells: [YearCell] = []

    var body: some View {
        let layout = GridLayout(
            screenWidth: UIScreen.main.bounds.width,
            availableHeight: availableHeight - titleHeight
        )
        // Use cached eager rows so the transition does not lazily build cells mid-gesture.
        let rows = gridRows(columnCount: layout.columns)

        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(String(format: "%d", calendar.component(.year, from: selectedDate)))
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if let onSettingsTap {
                    Button(action: onSettingsTap) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 23, weight: .thin))
                            .foregroundStyle(Theme.textSecondary.opacity(0.85))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, layout.padding)
            .padding(.top, 24)
            .frame(height: titleHeight, alignment: .top)

            VStack(spacing: layout.verticalSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: layout.horizontalSpacing) {
                        ForEach(row) { cell in
                            cellView(cell, layout: layout)
                        }
                    }
                }
            }
            .padding(.horizontal, layout.padding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshCache()
        }
        .onChange(of: selectedYear) { _, _ in
            refreshCache()
        }
        .onChange(of: summaryRevision) { _, _ in
            refreshCache()
        }
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
                .foregroundStyle(Theme.textSecondary)
                .frame(width: layout.cellSize, height: layout.cellSize)

        case .day(let date, let scores):
            let isToday = DateBoundary.dateString(from: date)
                == DateBoundary.dateString(from: DateBoundary.today())
            let isFuture = date > DateBoundary.today()

            Button { onDayTap(date) } label: {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Theme.productivity)
                            .frame(
                                width: layout.cellSize * 0.95,
                                height: layout.cellSize * 0.95
                            )
                    }

                    if isFuture {
                        Circle()
                            .stroke(
                                Theme.textQuaternary,
                                lineWidth: 0.75
                            )
                            .frame(
                                width: layout.cellSize * 0.7,
                                height: layout.cellSize * 0.7
                            )
                    } else {
                        MiniRingView(
                            scores: scores ?? [0, 0, 0, 0],
                            size: layout.cellSize * 0.95,
                            lineWidthRatio: 0.08,
                            gapRatio: 0.25
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

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var summaryRevision: Int {
        var hasher = Hasher()
        hasher.combine(selectedYear)

        for summary in summaries where summary.dateString.hasPrefix("\(selectedYear)-") {
            hasher.combine(summary.dateString)
            for score in summary.scores {
                hasher.combine(score.bitPattern)
            }
        }

        return hasher.finalize()
    }

    private func refreshCache() {
        let lookup = Dictionary(
            summaries
                .filter { $0.dateString.hasPrefix("\(selectedYear)-") }
                .map { ($0.dateString, $0.scores) },
            uniquingKeysWith: { first, _ in first }
        )

        cachedCells = buildCells(summaryLookup: lookup)
    }

    private func buildCells(summaryLookup: [String: [Double]]) -> [YearCell] {
        var result: [YearCell] = []
        let year = selectedYear

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

    private func gridRows(columnCount: Int) -> [[YearCell]] {
        guard columnCount > 0 else { return [] }

        return stride(from: 0, to: cachedCells.count, by: columnCount).map { startIndex in
            let endIndex = min(startIndex + columnCount, cachedCells.count)
            return Array(cachedCells[startIndex..<endIndex])
        }
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
