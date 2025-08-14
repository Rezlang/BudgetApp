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

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { r in
                    Text(r.title).tag(r)
                }
            }
            .pickerStyle(.segmented)

            Picker("Mode", selection: $mode) {
                ForEach(ChartMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value(mode == .spent ? "Spent" : "Remaining",
                                  mode == .spent ? pt.amount : max(category.limit - pt.amount, 0))
                    )
                }
            }
            .frame(height: 200)
        }
        .padding(.vertical)
    }
}
