import Foundation

@MainActor
final class PerformanceViewModel: ObservableObject {
    @Published var config: StrategyConfig
    @Published private(set) var result: PerformanceResult = .empty
    @Published private(set) var isComputing: Bool = false
    @Published private(set) var error: String?

    private var deals: [Dealing] = []
    private var currentBenchmark: MarketBenchmark = .ftseAllShare
    private var priceCache: [String: [PriceBar]] = [:]
    /// Keyed by benchmark ticker. Bars are already converted to GBP units
    /// for USD-denominated benchmarks (S&P 500, MSCI World), so downstream
    /// compute is unit-agnostic.
    private var benchmarkCache: [String: [PriceBar]] = [:]
    /// FX rates (GBP per USD), session-scoped. Used to convert USD benchmark
    /// bars into GBP-equivalent bars before compute.
    private var fxRates: [FxRate] = []
    private var computeTask: Task<Void, Never>?

    init() {
        self.config = Self.loadConfig()
    }

    // MARK: - External signals

    func apply(deals: [Dealing]) {
        // No-op if the dealing set hasn't actually changed — avoids a
        // redundant recompute cycle (and extra shimmer flash) when the
        // dashboard's poll republishes the same list.
        if self.deals.count == deals.count,
           zip(self.deals, deals).allSatisfy({ $0.id == $1.id }) {
            return
        }
        self.deals = deals
        scheduleRecompute(debounce: false)
    }

    func benchmarkChanged(to benchmark: MarketBenchmark) {
        guard benchmark != currentBenchmark else { return }
        // Invalidate the cached bars for the NEW benchmark ticker so we
        // re-fetch and re-convert (conversion depends on whether it's USD).
        benchmarkCache.removeValue(forKey: benchmark.ticker)
        currentBenchmark = benchmark
        scheduleRecompute(debounce: false)
    }

    func configChanged() {
        Self.saveConfig(config)
        scheduleRecompute(debounce: true)
    }

    // MARK: - Persistence (sticky knobs; excludedDealIds is session-only)

    private static let udPrefix = "ddbx.perf."

    private static func loadConfig() -> StrategyConfig {
        let ud = UserDefaults.standard
        let universe = ud.string(forKey: udPrefix + "universe")
            .flatMap(PerformanceUniverse.init(rawValue:)) ?? .suggested
        let window = ud.string(forKey: udPrefix + "timeWindow")
            .flatMap(PerformanceTimeWindow.init(rawValue:)) ?? .days90
        let exit = ud.string(forKey: udPrefix + "exitRule")
            .flatMap(PerformanceExitRule.init(rawValue:)) ?? .horizon90
        let amount = ud.string(forKey: udPrefix + "amount")
            .flatMap(PerformanceAmount.init(rawValue:)) ?? .gbp100
        let viewMode = ud.string(forKey: udPrefix + "viewMode")
            .flatMap(PerformanceViewMode.init(rawValue:)) ?? .realTerms
        return StrategyConfig(
            universe: universe,
            timeWindow: window,
            exitRule: exit,
            amount: amount,
            viewMode: viewMode,
            excludedDealIds: []
        )
    }

    private static func saveConfig(_ cfg: StrategyConfig) {
        let ud = UserDefaults.standard
        ud.set(cfg.universe.rawValue, forKey: udPrefix + "universe")
        ud.set(cfg.timeWindow.rawValue, forKey: udPrefix + "timeWindow")
        ud.set(cfg.exitRule.rawValue, forKey: udPrefix + "exitRule")
        ud.set(cfg.amount.rawValue, forKey: udPrefix + "amount")
        ud.set(cfg.viewMode.rawValue, forKey: udPrefix + "viewMode")
    }

    // MARK: - Scheduling

    /// Minimum wall-clock time the "computing" state stays visible after a
    /// recompute. Ensures knob tweaks are recognisable as transitions rather
    /// than instant swaps — even when the compute itself is cache-warm.
    private static let minVisibleComputeDuration: TimeInterval = 0.5

    private func scheduleRecompute(debounce: Bool) {
        computeTask?.cancel()
        isComputing = true
        computeTask = Task { [weak self] in
            let start = Date()
            if debounce {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }

            await self?.performCompute()

            // Enforce a minimum visible "computing" duration so users can see
            // a transition on knob changes. Debounce time counts toward it.
            let elapsed = Date().timeIntervalSince(start)
            let remaining = Self.minVisibleComputeDuration - elapsed
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.isComputing = false }
        }
    }

    // MARK: - Core compute

    /// Produces the next `PerformanceResult` without touching `isComputing` —
    /// that flag is managed entirely by `scheduleRecompute` so it can enforce
    /// a minimum visible duration.
    private func performCompute() async {
        let cfg = config
        let benchmark = currentBenchmark
        let windowStart = Self.windowCutoff(for: cfg.timeWindow)

        let filtered = deals.filter { deal in
            cfg.universe.matches(deal)
                && !cfg.excludedDealIds.contains(deal.id)
                && (windowStart == nil || deal.displayDate >= windowStart!)
        }

        guard !filtered.isEmpty else {
            result = .empty
            error = nil
            return
        }

        error = nil

        let tickers = Array(Set(filtered.map(\.ticker)))
        await fetchPriceHistories(tickers: tickers, benchmark: benchmark)

        guard !Task.isCancelled else { return }

        guard let benchBars = benchmarkCache[benchmark.ticker], !benchBars.isEmpty else {
            error = benchmark.isGbp
                ? "Benchmark price data unavailable."
                : "Benchmark or FX data unavailable — try again in a moment."
            result = .empty
            return
        }

        let next = computeResult(
            deals: filtered,
            config: cfg,
            priceCache: priceCache,
            benchmarkBars: benchBars
        )
        result = next
    }

    // MARK: - Price fetching

    private func fetchPriceHistories(tickers: [String], benchmark: MarketBenchmark) async {
        let missing = tickers.filter { priceCache[$0] == nil }
        let needsBench = benchmarkCache[benchmark.ticker] == nil
        let needsFx = !benchmark.isGbp && fxRates.isEmpty

        guard !missing.isEmpty || needsBench || needsFx else { return }

        enum FetchResult: Sendable {
            case ticker(String, [PriceBar]?)
            case benchmark(String, [PriceBar]?)
            case fx([FxRate]?)
        }

        let fetched: [FetchResult] = await withTaskGroup(of: FetchResult.self, returning: [FetchResult].self) { group in
            for ticker in missing {
                group.addTask {
                    let bars = try? await APIClient.shared.priceHistory(ticker: ticker, days: 730)
                    return .ticker(ticker, bars)
                }
            }
            if needsBench {
                let bTicker = benchmark.ticker
                group.addTask {
                    let bars = try? await APIClient.shared.priceHistory(ticker: bTicker, days: 730)
                    return .benchmark(bTicker, bars)
                }
            }
            if needsFx {
                group.addTask {
                    let rates = try? await APIClient.shared.gbpPerUsdHistory(days: 730)
                    return .fx(rates)
                }
            }
            var out: [FetchResult] = []
            for await entry in group {
                out.append(entry)
            }
            return out
        }

        for entry in fetched {
            switch entry {
            case .ticker(let t, let bars):
                priceCache[t] = bars ?? []
            case .benchmark(let t, let bars):
                // Defer storage until FX is merged in (below) — park raw bars.
                benchmarkCache[t] = bars ?? []
            case .fx(let rates):
                fxRates = rates ?? []
            }
        }

        // For USD benchmarks, replace cached bars with GBP-equivalent bars.
        if !benchmark.isGbp,
           let rawBars = benchmarkCache[benchmark.ticker],
           !rawBars.isEmpty,
           !fxRates.isEmpty {
            benchmarkCache[benchmark.ticker] = convertBarsToGbp(bars: rawBars, fx: fxRates)
        }
    }

    private func convertBarsToGbp(bars: [PriceBar], fx: [FxRate]) -> [PriceBar] {
        // FX is sparse (business days only). For each bar, use the last
        // FX rate on or before the bar's date. Drop bars for which no prior
        // rate exists (early in the series).
        var converted: [PriceBar] = []
        converted.reserveCapacity(bars.count)
        for bar in bars {
            guard let rate = lastFxRateOnOrBefore(rates: fx, date: bar.date) else { continue }
            converted.append(PriceBar(date: bar.date, closePence: bar.closePence * rate))
        }
        return converted
    }

    // MARK: - Window cutoff

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private static func windowCutoff(for window: PerformanceTimeWindow) -> String? {
        guard let days = window.days else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        guard let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) else { return nil }
        return iso.string(from: cutoff)
    }
}

// MARK: - Pure compute (testable)

struct ComputeEvent {
    let dealId: String
    let ticker: String
    let company: String
    let entryBarDate: String
    let entryPricePence: Double
    let strategyShares: Double
    let benchmarkShares: Double
    let deployed: Double
    let exitBarDate: String?
    let exitPricePence: Double?
    let benchmarkExitPricePence: Double?
}

func computeResult(
    deals: [Dealing],
    config: StrategyConfig,
    priceCache: [String: [PriceBar]],
    benchmarkBars: [PriceBar]
) -> PerformanceResult {

    let amountGbp = config.amount.pounds
    var events: [ComputeEvent] = []
    var droppedForData = 0

    for deal in deals {
        let disclosed = String(deal.displayDate.prefix(10))

        guard let tickerBars = priceCache[deal.ticker], !tickerBars.isEmpty else {
            droppedForData += 1
            continue
        }
        guard let entryBar = firstBarOnOrAfter(bars: tickerBars, date: disclosed),
              entryBar.closePence > 0 else {
            droppedForData += 1
            continue
        }
        guard let benchEntryBar = firstBarOnOrAfter(bars: benchmarkBars, date: disclosed),
              benchEntryBar.closePence > 0 else {
            droppedForData += 1
            continue
        }

        let strategyShares = (amountGbp * 100.0) / entryBar.closePence
        let benchShares = (amountGbp * 100.0) / benchEntryBar.closePence

        // Fixed-horizon exit date (M3 will wire; M2 always hold-forever)
        var exitBarDate: String? = nil
        var exitPrice: Double? = nil
        var benchExitPrice: Double? = nil

        if let horizon = config.exitRule.horizonDays,
           let targetDate = addDays(to: entryBar.date, days: horizon),
           let exitTickerBar = firstBarOnOrAfter(bars: tickerBars, date: targetDate),
           let exitBenchBar = firstBarOnOrAfter(bars: benchmarkBars, date: targetDate) {
            exitBarDate = exitTickerBar.date
            exitPrice = exitTickerBar.closePence
            benchExitPrice = exitBenchBar.closePence
        }

        events.append(ComputeEvent(
            dealId: deal.id,
            ticker: deal.ticker,
            company: deal.displayCompany,
            entryBarDate: entryBar.date,
            entryPricePence: entryBar.closePence,
            strategyShares: strategyShares,
            benchmarkShares: benchShares,
            deployed: amountGbp,
            exitBarDate: exitBarDate,
            exitPricePence: exitPrice,
            benchmarkExitPricePence: benchExitPrice
        ))
    }

    guard !events.isEmpty else {
        return PerformanceResult(
            strategy: [], benchmark: [], deployed: [], contributors: [],
            totalDeployed: 0, excludedForDataCount: droppedForData, dealCount: 0
        )
    }

    let earliest = events.map(\.entryBarDate).min()!
    let timeline = benchmarkBars.filter { $0.date >= earliest }

    var stratPoints: [PortfolioPoint] = []
    var benchPoints: [PortfolioPoint] = []
    var deployedPoints: [PortfolioPoint] = []

    for bar in timeline {
        let d = bar.date
        var stratValue: Double = 0
        var benchValue: Double = 0
        var deployedSoFar: Double = 0

        for event in events {
            guard d >= event.entryBarDate else { continue }
            deployedSoFar += event.deployed

            // Strategy leg
            if let exitDate = event.exitBarDate, d >= exitDate, let exitPx = event.exitPricePence {
                stratValue += event.strategyShares * exitPx / 100.0
            } else if let bars = priceCache[event.ticker],
                      let px = lastBarOnOrBefore(bars: bars, date: d),
                      px.closePence > 0 {
                stratValue += event.strategyShares * px.closePence / 100.0
            } else {
                stratValue += event.deployed
            }

            // Benchmark leg
            if let exitDate = event.exitBarDate, d >= exitDate, let benchExit = event.benchmarkExitPricePence {
                benchValue += event.benchmarkShares * benchExit / 100.0
            } else if let px = lastBarOnOrBefore(bars: benchmarkBars, date: d),
                      px.closePence > 0 {
                benchValue += event.benchmarkShares * px.closePence / 100.0
            } else {
                benchValue += event.deployed
            }
        }

        stratPoints.append(PortfolioPoint(date: d, value: stratValue))
        benchPoints.append(PortfolioPoint(date: d, value: benchValue))
        deployedPoints.append(PortfolioPoint(date: d, value: deployedSoFar))
    }

    let totalDeployed = events.map(\.deployed).reduce(0, +)

    let contributors: [ContributorRow] = events.map { event in
        let latestTickerPrice = priceCache[event.ticker]?.last?.closePence ?? event.entryPricePence
        let closed = event.exitPricePence != nil
        let valuePx = event.exitPricePence ?? latestTickerPrice
        let currentValue = event.strategyShares * valuePx / 100.0
        let returnPct = (currentValue - event.deployed) / event.deployed
        return ContributorRow(
            dealId: event.dealId,
            ticker: event.ticker,
            company: event.company,
            entryDate: event.entryBarDate,
            entryPricePence: event.entryPricePence,
            exitDate: event.exitBarDate,
            exitPricePence: event.exitPricePence,
            deployed: event.deployed,
            currentValue: currentValue,
            returnPct: returnPct,
            state: closed ? .closed : .open
        )
    }.sorted { abs($0.pnl) > abs($1.pnl) }

    return PerformanceResult(
        strategy: stratPoints,
        benchmark: benchPoints,
        deployed: deployedPoints,
        contributors: contributors,
        totalDeployed: totalDeployed,
        excludedForDataCount: droppedForData,
        dealCount: events.count
    )
}

// MARK: - Bar search helpers

func firstBarOnOrAfter(bars: [PriceBar], date: String) -> PriceBar? {
    // bars are already sorted by date ascending from the API
    var lo = 0, hi = bars.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if bars[mid].date < date { lo = mid + 1 } else { hi = mid }
    }
    return lo < bars.count ? bars[lo] : nil
}

func lastBarOnOrBefore(bars: [PriceBar], date: String) -> PriceBar? {
    var lo = 0, hi = bars.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if bars[mid].date <= date { lo = mid + 1 } else { hi = mid }
    }
    return lo > 0 ? bars[lo - 1] : nil
}

func lastFxRateOnOrBefore(rates: [FxRate], date: String) -> Double? {
    var lo = 0, hi = rates.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if rates[mid].date <= date { lo = mid + 1 } else { hi = mid }
    }
    return lo > 0 ? rates[lo - 1].gbpPerUsd : nil
}

func addDays(to isoDate: String, days: Int) -> String? {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "Europe/London")
    guard let date = f.date(from: String(isoDate.prefix(10))) else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
    guard let added = cal.date(byAdding: .day, value: days, to: date) else { return nil }
    return f.string(from: added)
}
