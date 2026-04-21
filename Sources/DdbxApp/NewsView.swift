import SafariServices
import SwiftUI

struct NewsView: View {
    @Environment(\.ddbxColors) private var colors
    @State private var news: [UkNewsItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedURL: URL?
    @State private var showAbout = false
    @State private var selectedSource: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                if isLoading && news.isEmpty {
                    SkeletonNews()
                } else if let error, news.isEmpty {
                    errorState(error)
                } else {
                    newsList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LogoButton(showAbout: $showAbout)
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutSheet()
            }
            .refreshable { await loadNews() }
        }
        .task { await loadNews() }
        .sheet(item: $selectedURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    // MARK: - List

    private var newsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                HStack {
                    Text("News")
                        .font(.instrument(.bold, size: 28))
                        .foregroundStyle(colors.foreground)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                sourceFilterBar

                ForEach(groupedNews, id: \.key) { group in
                    Section {
                        ForEach(group.items) { item in
                            newsRow(item)

                            if item.id != group.items.last?.id {
                                Divider()
                                    .overlay(colors.separator)
                                    .padding(.leading, 56)
                            }
                        }
                    } header: {
                        dayHeader(group.label)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var sourceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sourceChip(label: "All", active: selectedSource == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSource = nil }
                }
                ForEach(availableSources, id: \.self) { source in
                    sourceChip(label: source, active: selectedSource == source) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSource = selectedSource == source ? nil : source
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func sourceChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.instrument(.medium, size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? colors.accent.opacity(0.15) : colors.surfaceSecondary, in: Capsule())
                .foregroundStyle(active ? colors.accent : colors.muted)
        }
    }

    private var availableSources: [String] {
        var seen = Set<String>()
        return news.compactMap { item -> String? in
            guard !seen.contains(item.source) else { return nil }
            seen.insert(item.source)
            return item.source
        }
    }

    private func dayHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.instrument(.semiBold, size: 12))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(colors.muted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.background)
    }

    private func newsRow(_ item: UkNewsItem) -> some View {
        Button {
            if let url = URL(string: item.url) {
                selectedURL = url
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Favicon
                if let domain = item.domain {
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=32")) { image in
                        image.resizable()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors.surfaceSecondary)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.source)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.accent)
                        .lineLimit(1)

                    Text(item.title)
                        .font(.instrument(size: 14))
                        .foregroundStyle(colors.foreground)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.muted)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.title)
                .foregroundStyle(colors.muted)
            Text(message)
                .font(.instrument(size: 15))
                .foregroundStyle(colors.muted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadNews() }
            }
            .font(.instrument(.semiBold, size: 15))
            .foregroundStyle(colors.accent)
        }
        .padding()
    }

    // MARK: - Grouping

    private struct NewsGroup {
        let key: String
        let label: String
        let items: [UkNewsItem]
    }

    private var groupedNews: [NewsGroup] {
        let filtered = selectedSource.map { src in news.filter { $0.source == src } } ?? news
        let todayKey = Self.ukDayFormatter.string(from: Date())
        var order: [String] = []
        var buckets: [String: [UkNewsItem]] = [:]

        for item in filtered {
            let key = Self.dayKey(for: item.publishedAt) ?? ""
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }

        return order.map { key in
            NewsGroup(
                key: key,
                label: label(for: key, todayKey: todayKey),
                items: buckets[key] ?? []
            )
        }
    }

    private func label(for key: String, todayKey: String) -> String {
        if key.isEmpty { return "Earlier" }
        if key == todayKey { return "Today" }
        guard let date = Self.ukDayFormatter.date(from: key) else { return key }
        return Self.ukDayLabelFormatter.string(from: date)
    }

    private static func dayKey(for isoTimestamp: String?) -> String? {
        guard let iso = isoTimestamp else { return nil }
        if let date = ISO8601DateFormatter.ddbxWithFractional.date(from: iso)
            ?? ISO8601DateFormatter.ddbxStandard.date(from: iso) {
            return ukDayFormatter.string(from: date)
        }
        return nil
    }

    private static let ukTimeZone = TimeZone(identifier: "Europe/London")!

    private static let ukDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = ukTimeZone
        return f
    }()

    private static let ukDayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = ukTimeZone
        return f
    }()

    // MARK: - Data

    private func loadNews() async {
        isLoading = true
        error = nil
        do {
            let response = try await APIClient.shared.ukNews()
            news = response.items
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Safari wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let ddbxWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let ddbxStandard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
