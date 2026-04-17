import Foundation

@Observable @MainActor
final class DashboardViewModel {
    private(set) var dealings: [Dealing] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private var versionFingerprint: String?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Grouped data

    /// Today's deals (UK timezone, based on disclosed_date ?? trade_date)
    var todayAnalysed: [Dealing] {
        todayDealings.filter(\.isSuggested)
    }

    var todaySkipped: [Dealing] {
        todayDealings.filter { !$0.isSuggested }
    }

    /// History: everything not from today, newest first
    var history: [Dealing] {
        dealings.filter { !isToday($0) }
    }

    /// Grouped history by month-year
    var historyByMonth: [(key: String, deals: [Dealing])] {
        let grouped = Dictionary(grouping: history) { monthKey($0.displayDate) }
        return grouped
            .map { (key: $0.key, deals: $0.value) }
            .sorted { $0.deals.first?.displayDate ?? "" > $1.deals.first?.displayDate ?? "" }
    }

    /// Two-tier grouping: month → days within that month → deals on that day.
    /// Months and days both sorted newest-first.
    var historyByMonthAndDay: [MonthGroup] {
        let sorted = history.sorted { $0.displayDate > $1.displayDate }

        var months: [(key: String, order: Int, days: [String: [Dealing]], dayOrder: [String])] = []
        var monthIndex: [String: Int] = [:]

        for deal in sorted {
            let mKey = monthKey(deal.displayDate)
            let dKey = deal.displayDate
            if let idx = monthIndex[mKey] {
                if months[idx].days[dKey] == nil {
                    months[idx].dayOrder.append(dKey)
                }
                months[idx].days[dKey, default: []].append(deal)
            } else {
                monthIndex[mKey] = months.count
                months.append((key: mKey, order: months.count, days: [dKey: [deal]], dayOrder: [dKey]))
            }
        }

        return months.map { month in
            MonthGroup(
                key: month.key,
                days: month.dayOrder.map { dKey in
                    DayGroup(key: dKey, label: dayLabel(dKey), deals: month.days[dKey] ?? [])
                }
            )
        }
    }

    struct MonthGroup: Identifiable {
        let key: String
        let days: [DayGroup]
        var id: String { key }
    }

    struct DayGroup: Identifiable {
        let key: String
        let label: String
        let deals: [Dealing]
        var id: String { key }
    }

    /// Flat day list spanning all history months — used by the dashboard's
    /// single-tier sticky day headers. `isFirstOfMonth` flags the first day
    /// within each month so its header can render the month label on top.
    struct FlatDayGroup: Identifiable {
        let key: String
        let dayLabel: String
        let monthKey: String
        let monthLabel: String
        let isFirstOfMonth: Bool
        let deals: [Dealing]
        var id: String { key }
    }

    var historyByDay: [FlatDayGroup] { flatDayGroups(from: history) }

    /// All dealings (including today) as flat day groups — used when filter
    /// collapses the Today section into the chronological stream.
    var allByDay: [FlatDayGroup] { flatDayGroups(from: dealings) }

    private func flatDayGroups(from source: [Dealing]) -> [FlatDayGroup] {
        let sorted = source.sorted { $0.displayDate > $1.displayDate }
        var months: [(key: String, days: [String: [Dealing]], dayOrder: [String])] = []
        var monthIndex: [String: Int] = [:]
        for deal in sorted {
            let mKey = monthKey(deal.displayDate)
            let dKey = deal.displayDate
            if let idx = monthIndex[mKey] {
                if months[idx].days[dKey] == nil { months[idx].dayOrder.append(dKey) }
                months[idx].days[dKey, default: []].append(deal)
            } else {
                monthIndex[mKey] = months.count
                months.append((key: mKey, days: [dKey: [deal]], dayOrder: [dKey]))
            }
        }
        var result: [FlatDayGroup] = []
        for month in months {
            for (index, dKey) in month.dayOrder.enumerated() {
                result.append(FlatDayGroup(
                    key: dKey,
                    dayLabel: dayLabel(dKey),
                    monthKey: month.key,
                    monthLabel: month.key,
                    isFirstOfMonth: index == 0,
                    deals: month.days[dKey] ?? []
                ))
            }
        }
        return result
    }

    // MARK: - Lift + FTSE

    private(set) var liftPrices: [String: Double] = [:]  // ticker → latest price_pence
    private(set) var ftseHistory: [PriceBar] = []
    private(set) var ftseLatest: Double?
    private(set) var liftLoading = false

    func fetchLiftPrices(benchmarkTicker: String = "^FTAS") async {
        guard !liftLoading else { return }
        let tickers = Array(Set(dealings.map(\.ticker)))
        guard !tickers.isEmpty else { return }
        liftLoading = true
        async let stockTask = APIClient.shared.latestPrices(tickers: tickers)
        async let ftseHistTask = APIClient.shared.priceHistory(ticker: benchmarkTicker, days: 730)
        async let ftseLatTask = APIClient.shared.latestPrices(tickers: [benchmarkTicker])
        if let prices = try? await stockTask {
            for p in prices { liftPrices[p.ticker] = p.pricePence }
        }
        if let history = try? await ftseHistTask { ftseHistory = history }
        if let latest = try? await ftseLatTask { ftseLatest = latest.first?.pricePence }
        liftLoading = false
    }

    func liftPct(for deal: Dealing) -> Double? {
        guard let latest = liftPrices[deal.ticker], deal.pricePence > 0 else { return nil }
        return (latest - deal.pricePence) / deal.pricePence
    }

    func ftsePct(for deal: Dealing) -> Double? {
        let date = String(deal.tradeDate.prefix(10))
        guard let bar = ftseHistory.last(where: { $0.date <= date }),
              let current = ftseLatest, bar.closePence > 0 else { return nil }
        return (current - bar.closePence) / bar.closePence
    }

    // MARK: - Lifecycle

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            // Initial load
            await self?.refresh()
            // Poll every 30s
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.checkVersion()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        isLoading = dealings.isEmpty
        error = nil
        do {
            let fetched = try await APIClient.shared.dealings()
            dealings = fetched
            let v = try await APIClient.shared.version()
            versionFingerprint = "\(v.latest ?? ""):\(v.total)"
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Private

    private func checkVersion() async {
        do {
            let v = try await APIClient.shared.version()
            let fp = "\(v.latest ?? ""):\(v.total)"
            if fp != versionFingerprint {
                versionFingerprint = fp
                await refresh()
            }
        } catch {
            // Silently retry next cycle
        }
    }

    private var todayDealings: [Dealing] {
        dealings.filter { isToday($0) }
    }

    private func isToday(_ dealing: Dealing) -> Bool {
        let dateStr = dealing.displayDate
        let today = Self.ukDateFormatter.string(from: Date())
        return dateStr == today
    }

    private func monthKey(_ dateStr: String) -> String {
        guard let date = Self.isoDateParser.date(from: dateStr) else { return dateStr }
        return Self.monthFormatter.string(from: date)
    }

    private func dayLabel(_ dateStr: String) -> String {
        guard let date = Self.isoDateParser.date(from: dateStr) else { return dateStr }
        return Self.dayLabelFormatter.string(from: date)
    }

    private static let ukTimeZone = TimeZone(identifier: "Europe/London")!

    private static let ukDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = ukTimeZone
        return f
    }()

    private static let isoDateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = ukTimeZone
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone = ukTimeZone
        return f
    }()

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = ukTimeZone
        return f
    }()
}
