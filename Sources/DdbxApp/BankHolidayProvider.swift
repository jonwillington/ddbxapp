import Foundation

@MainActor
final class BankHolidayProvider: ObservableObject {
    static let shared = BankHolidayProvider()

    @Published private(set) var englandAndWales: [Date: String] = [:]

    private let bundleResource = "bank-holidays"
    private let cacheFilename = "bank-holidays.json"
    private let lastFetchKey = "bankHolidaysLastFetch"
    private let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private let feedURL = URL(string: "https://www.gov.uk/bank-holidays.json")!

    private let session: URLSession
    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    init(session: URLSession = .shared) {
        self.session = session
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = LSE.timeZone
        self.calendar = cal

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = LSE.timeZone
        f.locale = Locale(identifier: "en_GB_POSIX")
        self.dateFormatter = f

        loadFromDisk()
    }

    func holiday(on date: Date) -> String? {
        englandAndWales[calendar.startOfDay(for: date)]
    }

    func refreshIfStale() async {
        let last = UserDefaults.standard.double(forKey: lastFetchKey)
        if last > 0, Date().timeIntervalSince1970 - last < refreshInterval {
            return
        }
        await refresh()
    }

    func refresh() async {
        do {
            let (data, response) = try await session.data(from: feedURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            guard let decoded = decode(data) else { return }
            englandAndWales = decoded
            if let cacheURL = cachedFileURL() {
                try? data.write(to: cacheURL, options: .atomic)
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
        } catch {
            // Network failed — keep whatever snapshot we already have.
        }
    }

    private func loadFromDisk() {
        if let cacheURL = cachedFileURL(),
           let data = try? Data(contentsOf: cacheURL),
           let decoded = decode(data) {
            englandAndWales = decoded
            return
        }
        if let bundleURL = Bundle.main.url(forResource: bundleResource, withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let decoded = decode(data) {
            englandAndWales = decoded
        }
    }

    private func decode(_ data: Data) -> [Date: String]? {
        struct Payload: Decodable {
            struct Region: Decodable {
                struct Event: Decodable {
                    let title: String
                    let date: String
                }
                let events: [Event]
            }
            let englandAndWales: Region

            enum CodingKeys: String, CodingKey {
                case englandAndWales = "england-and-wales"
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        var map: [Date: String] = [:]
        for event in payload.englandAndWales.events {
            guard let parsed = dateFormatter.date(from: event.date) else { continue }
            map[calendar.startOfDay(for: parsed)] = event.title
        }
        return map
    }

    private func cachedFileURL() -> URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return dir.appendingPathComponent(cacheFilename)
    }
}
