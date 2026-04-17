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
        return response.dealings
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
