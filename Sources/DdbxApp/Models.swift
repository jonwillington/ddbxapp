import Foundation

// MARK: - Dealing

struct Dealing: Codable, Identifiable, Sendable {
    let id: String
    let tradeDate: String
    let disclosedDate: String
    let createdAt: String?
    let director: DirectorSummary
    let ticker: String
    let company: String
    let txType: TransactionType
    let shares: Int
    let pricePence: Double
    let valueGbp: Double
    let triage: Triage?
    let analysis: Analysis?
    let performance: [PerformanceRow]?
    let sector: String?
    /// Raw API string. Use `sectorNormalized` to access the enum; a future
    /// server-side bucket we don't know about decodes to a non-nil string but
    /// resolves to nil here, instead of breaking the whole Dealing decode.
    private let sectorNormalizedRaw: String?
    let sicCodes: [String]?

    var sectorNormalized: SectorNormalized? {
        sectorNormalizedRaw.flatMap(SectorNormalized.init(rawValue:))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tradeDate = "trade_date"
        case disclosedDate = "disclosed_date"
        case createdAt = "created_at"
        case director, ticker, company
        case txType = "tx_type"
        case shares
        case pricePence = "price_pence"
        case valueGbp = "value_gbp"
        case triage, analysis, performance
        case sector
        case sectorNormalizedRaw = "sector_normalized"
        case sicCodes = "sic_codes"
    }

    /// The date used for display grouping (disclosed preferred, falls back to trade)
    var displayDate: String { disclosedDate.isEmpty ? tradeDate : disclosedDate }

    /// Company name with the trailing ticker bracket (e.g. " (BKG)") stripped.
    /// API returns strings like "Berkeley Group Holdings (The) (BKG)" — only the
    /// ticker-matching bracket is removed; other parenthetical suffixes (like "(DI)")
    /// are preserved.
    var displayCompany: String {
        let short = ticker.replacingOccurrences(of: ".L", with: "")
        let candidates = [" (\(short))", " (\(ticker))"]
        var name = company.trimmingCharacters(in: .whitespaces)
        for suffix in candidates where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name
    }

    /// Matches `isSuggestedDealing` from dd-site
    var isSuggested: Bool {
        guard let analysis else { return false }
        return analysis.rating != .routine
    }
}

// MARK: - Transaction type

enum TransactionType: String, Codable, Sendable {
    case buy
    case sell
}

// MARK: - Director

struct DirectorSummary: Codable, Sendable {
    let id: String
    let name: String
    let role: String
    let company: String
    let ageBand: String?
    let tenureYears: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, role, company
        case ageBand = "age_band"
        case tenureYears = "tenure_years"
    }
}

// MARK: - Triage

struct Triage: Codable, Sendable {
    let verdict: TriageVerdict
    let reason: String
}

enum TriageVerdict: String, Codable, Sendable {
    case skip
    case maybe
    case promising
}

// MARK: - Analysis

struct Analysis: Codable, Sendable {
    let rating: Rating
    let confidence: Double
    let summary: String
    let thesisPoints: [String]
    let evidenceFor: [EvidencePoint]
    let evidenceAgainst: [EvidencePoint]
    let keyRisks: [String]
    let catalystWindow: String
    let ratingRationale: String?
    let checklist: RatingChecklist?

    enum CodingKeys: String, CodingKey {
        case rating, confidence, summary
        case thesisPoints = "thesis_points"
        case evidenceFor = "evidence_for"
        case evidenceAgainst = "evidence_against"
        case keyRisks = "key_risks"
        case catalystWindow = "catalyst_window"
        case ratingRationale = "rating_rationale"
        case checklist
    }
}

struct RatingChecklist: Codable, Sendable {
    let openMarketBuy: Bool
    let seniorInsider: Bool
    let meaningfulConviction: Bool
    let noAlternativeExplanation: Bool
    let supportingContextFound: Bool
    let noMajorCounterSignal: Bool

    enum CodingKeys: String, CodingKey {
        case openMarketBuy = "open_market_buy"
        case seniorInsider = "senior_insider"
        case meaningfulConviction = "meaningful_conviction"
        case noAlternativeExplanation = "no_alternative_explanation"
        case supportingContextFound = "supporting_context_found"
        case noMajorCounterSignal = "no_major_counter_signal"
    }

    nonisolated(unsafe) static let labels: [(keyPath: KeyPath<RatingChecklist, Bool>, label: String)] = [
        (\.openMarketBuy, "Open-market buy"),
        (\.seniorInsider, "Senior insider"),
        (\.meaningfulConviction, "Meaningful conviction"),
        (\.noAlternativeExplanation, "No scheme or plan"),
        (\.supportingContextFound, "Supporting context found"),
        (\.noMajorCounterSignal, "No major counter-signal"),
    ]

    var passedCount: Int {
        Self.labels.count(where: { self[keyPath: $0.keyPath] })
    }
}

enum Rating: String, Codable, Sendable, CaseIterable {
    case significant
    case noteworthy
    case minor
    case routine
}

struct EvidencePoint: Codable, Sendable {
    let headline: String
    let detail: String
    let sourceLabel: String
    let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case headline, detail
        case sourceLabel = "source_label"
        case sourceUrl = "source_url"
    }
}

// MARK: - Sector

/// ICB top-level industries. Mirrors the dd-site `SectorNormalized` enum
/// returned on the Dealing payload. Closed enum — must stay in sync with
/// `worker/db/types.ts`. Add a case here in the same release that adds one
/// server-side; otherwise older builds would fail to decode dealings.
enum SectorNormalized: String, Codable, CaseIterable, Sendable {
    case technology = "Technology"
    case telecommunications = "Telecommunications"
    case healthCare = "Health Care"
    case financials = "Financials"
    case realEstate = "Real Estate"
    case consumerDiscretionary = "Consumer Discretionary"
    case consumerStaples = "Consumer Staples"
    case industrials = "Industrials"
    case basicMaterials = "Basic Materials"
    case energy = "Energy"
    case utilities = "Utilities"

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .technology: return "Tech"
        case .telecommunications: return "Telecoms"
        case .healthCare: return "Health"
        case .financials: return "Financials"
        case .realEstate: return "Real Estate"
        case .consumerDiscretionary: return "Cons. Disc."
        case .consumerStaples: return "Cons. Staples"
        case .industrials: return "Industrials"
        case .basicMaterials: return "Materials"
        case .energy: return "Energy"
        case .utilities: return "Utilities"
        }
    }
}

// MARK: - Performance

struct PerformanceRow: Codable, Sendable {
    let horizonDays: Int
    let returnPct: Double?
    let asOfDate: String?

    enum CodingKeys: String, CodingKey {
        case horizonDays = "horizon_days"
        case returnPct = "return_pct"
        case asOfDate = "as_of_date"
    }
}

// MARK: - API response wrappers

struct DealingsResponse: Codable, Sendable {
    let dealings: [Dealing]
}

struct VersionResponse: Codable, Sendable {
    let latest: String?
    let total: Int
}

// MARK: - UK News

struct UkNewsItem: Codable, Identifiable, Sendable {
    let title: String
    let url: String
    let source: String
    let publishedAt: String?

    var id: String { url }

    enum CodingKeys: String, CodingKey {
        case title, url, source
        case publishedAt = "published_at"
    }

    var domain: String? {
        URL(string: url).flatMap(\.host)
    }
}

struct UkNewsResponse: Codable, Sendable {
    let items: [UkNewsItem]
    let fetchedAt: String?

    enum CodingKeys: String, CodingKey {
        case items
        case fetchedAt = "fetched_at"
    }
}

// MARK: - Prices

struct LatestPrice: Codable, Sendable {
    let ticker: String
    let pricePence: Double
    let date: String

    enum CodingKeys: String, CodingKey {
        case ticker
        case pricePence = "price_pence"
        case date
    }
}

struct LatestPricesResponse: Codable, Sendable {
    let prices: [LatestPrice]
}

// MARK: - Price history

struct PriceBar: Codable, Sendable {
    let date: String
    let closePence: Double

    enum CodingKeys: String, CodingKey {
        case date
        case closePence = "close_pence"
    }
}

struct PriceHistoryResponse: Codable, Sendable {
    let bars: [PriceBar]
}

struct PriceOnResponse: Codable, Sendable {
    let price: Double?
}

// MARK: - FX

struct FxRate: Sendable, Equatable {
    let date: String       // yyyy-MM-dd
    let gbpPerUsd: Double
}

struct FxTimeseries: Codable, Sendable {
    /// Frankfurter shape: { "rates": { "2026-04-21": { "GBP": 0.74 } } }
    let rates: [String: [String: Double]]
}
