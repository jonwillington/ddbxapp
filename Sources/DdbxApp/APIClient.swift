import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.ddbx.uk/api")!
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - Dealings

    func dealings() async throws -> [Dealing] {
        let url = baseURL.appendingPathComponent("dealings")
        let response: DealingsResponse = try await fetch(url)
        return response.dealings.filter { $0.valueGbp > 0 && $0.pricePence > 0 }
    }

    func dealing(id: String) async throws -> Dealing {
        let url = baseURL.appendingPathComponent("dealings/\(id)")
        return try await fetch(url)
    }

    // MARK: - Version (for polling)

    func version() async throws -> VersionResponse {
        let url = baseURL.appendingPathComponent("version")
        return try await fetch(url)
    }

    // MARK: - News

    func ukNews() async throws -> UkNewsResponse {
        let url = baseURL.appendingPathComponent("news/uk")
        return try await fetch(url)
    }

    // MARK: - Prices

    func latestPrices(tickers: [String]) async throws -> [LatestPrice] {
        var components = URLComponents(url: baseURL.appendingPathComponent("prices/latest"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "tickers", value: tickers.joined(separator: ","))]
        let response: LatestPricesResponse = try await fetch(components.url!)
        return response.prices
    }

    func priceHistory(ticker: String, days: Int = 365) async throws -> [PriceBar] {
        var components = URLComponents(url: baseURL.appendingPathComponent("prices/history"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "days", value: "\(days)"),
        ]
        let response: PriceHistoryResponse = try await fetch(components.url!)
        return response.bars
    }

    func priceOn(ticker: String, date: String) async throws -> Double? {
        var components = URLComponents(url: baseURL.appendingPathComponent("prices/on"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "date", value: date),
        ]
        let response: PriceOnResponse = try await fetch(components.url!)
        return response.price
    }

    // MARK: - FX (ECB daily rates via Frankfurter)

    /// Daily GBP-per-USD rates for the last `days`. ECB only publishes on
    /// business days, so callers should treat the series as sparse and
    /// use the last rate on or before a given date.
    func gbpPerUsdHistory(days: Int = 730) async throws -> [FxRate] {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -max(days, 1), to: end) else {
            return []
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        let startStr = f.string(from: start)
        let endStr = f.string(from: end)
        guard let url = URL(string: "https://api.frankfurter.dev/v1/\(startStr)..\(endStr)?base=USD&symbols=GBP") else {
            return []
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try decoder.decode(FxTimeseries.self, from: data)
        return decoded.rates.compactMap { (date, m) in
            guard let r = m["GBP"] else { return nil }
            return FxRate(date: date, gbpPerUsd: r)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.badStatus(code)
        }
        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: Error, LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "Server returned \(code)"
        }
    }
}
