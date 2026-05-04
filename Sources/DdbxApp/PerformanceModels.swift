import Foundation

// MARK: - Universe

enum PerformanceUniverse: String, CaseIterable, Codable, Sendable {
    case everyBuy
    case suggested
    case significant
    case noteworthy

    var displayName: String {
        switch self {
        case .everyBuy:    "Every buy"
        case .suggested:   "Suggested"
        case .significant: "Significant"
        case .noteworthy:  "Noteworthy"
        }
    }

    func matches(_ deal: Dealing) -> Bool {
        guard deal.txType == .buy else { return false }
        switch self {
        case .everyBuy:    return true
        case .suggested:   return deal.isSuggested
        case .significant: return deal.analysis?.rating == .significant
        case .noteworthy:  return deal.analysis?.rating == .noteworthy
        }
    }
}

// MARK: - Time window (how far back we include deals)

enum PerformanceTimeWindow: String, CaseIterable, Codable, Sendable {
    case days30
    case days90
    case days365
    case all

    var displayName: String {
        switch self {
        case .days30:  "30d"
        case .days90:  "90d"
        case .days365: "1y"
        case .all:     "All"
        }
    }

    /// nil = unbounded (capped by 730-day history limit at compute time)
    var days: Int? {
        switch self {
        case .days30:  30
        case .days90:  90
        case .days365: 365
        case .all:     nil
        }
    }
}

// MARK: - Exit rule

enum PerformanceExitRule: String, CaseIterable, Codable, Sendable {
    case horizon30
    case horizon90
    case horizon180
    case horizon365
    case holdForever

    var displayName: String {
        switch self {
        case .horizon30:   "30d hold"
        case .horizon90:   "90d hold"
        case .horizon180:  "180d hold"
        case .horizon365:  "1y hold"
        case .holdForever: "Hold forever"
        }
    }

    /// nil = hold forever
    var horizonDays: Int? {
        switch self {
        case .horizon30:   30
        case .horizon90:   90
        case .horizon180:  180
        case .horizon365:  365
        case .holdForever: nil
        }
    }
}

// MARK: - Amount per deal

enum PerformanceAmount: String, CaseIterable, Codable, Sendable {
    case gbp100
    case gbp500
    case gbp1000

    var displayName: String {
        switch self {
        case .gbp100:  "£100"
        case .gbp500:  "£500"
        case .gbp1000: "£1,000"
        }
    }

    var pounds: Double {
        switch self {
        case .gbp100:  100
        case .gbp500:  500
        case .gbp1000: 1_000
        }
    }
}

// MARK: - View mode

enum PerformanceViewMode: String, CaseIterable, Codable, Sendable {
    case realTerms
    case vsMarket

    var displayName: String {
        switch self {
        case .realTerms: "Real terms"
        case .vsMarket:  "vs Market"
        }
    }
}

// MARK: - Performance mode (Overall vs By Industry)

enum PerformanceMode: String, CaseIterable, Codable, Sendable {
    case overall
    case byIndustry

    var displayName: String {
        switch self {
        case .overall:    "Overall"
        case .byIndustry: "By Industry"
        }
    }
}

// MARK: - Config

struct StrategyConfig: Equatable {
    var mode: PerformanceMode
    var universe: PerformanceUniverse
    var timeWindow: PerformanceTimeWindow
    var exitRule: PerformanceExitRule
    var amount: PerformanceAmount
    var viewMode: PerformanceViewMode
    /// Session-only — deals the user has removed from the backtest.
    /// Applied symmetrically to both legs.
    var excludedDealIds: Set<String>

    static let `default` = StrategyConfig(
        mode: .overall,
        universe: .suggested,
        timeWindow: .days90,
        exitRule: .horizon90,
        amount: .gbp100,
        viewMode: .realTerms,
        excludedDealIds: []
    )
}

// MARK: - Result

struct PortfolioPoint: Equatable, Sendable {
    let date: String   // yyyy-MM-dd
    let value: Double  // £
}

struct ContributorRow: Identifiable, Equatable {
    enum State: Equatable {
        case open       // hold-forever, or fixed-horizon not yet reached
        case closed     // exit date passed, realized
        case delisted   // no data past some point; last known close carried
    }

    let dealId: String
    let ticker: String
    let company: String
    let entryDate: String
    let entryPricePence: Double
    let exitDate: String?
    let exitPricePence: Double?
    let deployed: Double
    let currentValue: Double
    let returnPct: Double
    let state: State

    var id: String { dealId }
    var pnl: Double { currentValue - deployed }
}

struct PerformanceResult: Equatable {
    let strategy: [PortfolioPoint]
    let benchmark: [PortfolioPoint]
    /// Cumulative capital deployed at each timeline point. Used by the
    /// chart to render meaningful % at every index (early-stage points
    /// would be misleading if divided by the final total-deployed).
    let deployed: [PortfolioPoint]
    let contributors: [ContributorRow]
    let totalDeployed: Double
    let excludedForDataCount: Int
    let dealCount: Int

    var strategyFinalValue: Double { strategy.last?.value ?? 0 }
    var benchmarkFinalValue: Double { benchmark.last?.value ?? 0 }

    var strategyReturnPct: Double {
        guard totalDeployed > 0 else { return 0 }
        return (strategyFinalValue - totalDeployed) / totalDeployed
    }

    var benchmarkReturnPct: Double {
        guard totalDeployed > 0 else { return 0 }
        return (benchmarkFinalValue - totalDeployed) / totalDeployed
    }

    /// Money-weighted alpha in £.
    var alphaGbp: Double { strategyFinalValue - benchmarkFinalValue }
    var alphaReturnPct: Double { strategyReturnPct - benchmarkReturnPct }

    static let empty = PerformanceResult(
        strategy: [],
        benchmark: [],
        deployed: [],
        contributors: [],
        totalDeployed: 0,
        excludedForDataCount: 0,
        dealCount: 0
    )
}

// MARK: - Sector result (per-industry leaderboard row)

struct SectorResult: Identifiable, Equatable {
    let sector: SectorNormalized
    let result: PerformanceResult

    var id: String { sector.rawValue }
    var dealCount: Int { result.dealCount }
    var alphaPp: Double { result.alphaReturnPct * 100 }
}
