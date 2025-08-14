import SwiftUI
import Charts

struct BudgetHistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

enum ChartMode: String, CaseIterable, Identifiable {
    case spent
    case remaining
    var id: Self { self }
    var title: String { self == .spent ? "Spent" : "Remaining" }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case currentMonth = "Month"
    case past30d = "30d"
    case threeM = "3m"
    case sixM = "6m"
    case year = "Year"
    case all = "All"
    var id: Self { self }
    var title: String { rawValue }
    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .currentMonth:
            let comps = cal.dateComponents([.year, .month], from: Date())
            return cal.date(from: comps) ?? Date()
        case .past30d:
            return cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .threeM:
            return cal.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .sixM:
            return cal.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .year:
            return cal.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case .all:
            return .distantPast
        }
    }
}

struct BudgetHistoryChart: View {
    var category: CategoryItem
    var purchases: [Purchase]
    @State private var range: TimeRange = .currentMonth
    @State private var mode: ChartMode = .spent
    @State private var selectedPoint: BudgetHistoryPoint?

    private var filtered: [Purchase] {
        let start = range.startDate
        return purchases.filter { $0.date >= start }
    }

    private var points: [BudgetHistoryPoint] {
        let cal = Calendar.current
        let sorted = filtered.sorted { $0.date < $1.date }
        var running: Double = 0
        var out: [BudgetHistoryPoint] = []
        for p in sorted {
            running += p.amount
            let day = cal.startOfDay(for: p.date)
            if let idx = out.firstIndex(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                out[idx] = BudgetHistoryPoint(date: day, amount: running)
            } else {
                out.append(BudgetHistoryPoint(date: day, amount: running))
            }
        }
        return out
    }

    private var displayAmount: Double {
        let base: Double
        if let sel = selectedPoint {
            base = sel.amount
        } else {
            base = points.last?.amount ?? 0
        }
        return mode == .spent ? base : max(category.limit - base, 0)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(mode == .spent ? "Total Spent" : "Remaining"): \(displayAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                .font(.headline)

            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { r in
                    Text(r.title).tag(r)
                }
            }
            .pickerStyle(.segmented)

            .onChange(of: range) { _, _ in selectedPoint = nil }

            Picker("Mode", selection: $mode) {
                ForEach(ChartMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)

            .onChange(of: mode) { _, _ in selectedPoint = nil }

            let yLabel = mode == .spent ? "Spent" : "Remaining"
            Chart {
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value(yLabel, mode == .spent ? pt.amount : max(category.limit - pt.amount, 0))
                    )
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value(yLabel, mode == .spent ? pt.amount : max(category.limit - pt.amount, 0))
                    )
                    .symbolSize(selectedPoint?.id == pt.id ? 150 : 50)
                }
                if let sel = selectedPoint {
                    RuleMark(
                        x: .value("Date", sel.date),
                        yStart: .value(yLabel, 0),
                        yEnd: .value(yLabel, mode == .spent ? sel.amount : max(category.limit - sel.amount, 0))
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.gray)
                }
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        let day = Calendar.current.startOfDay(for: date)
                                        if let match = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                                            if selectedPoint?.id == match.id {
                                                selectedPoint = nil
                                            } else {
                                                selectedPoint = match
                                            }
                                        }
                                    }
                                }
                        )
                }
            }
        }
        .padding(.vertical)
    }
}
