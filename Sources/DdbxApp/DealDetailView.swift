import SafariServices
import SwiftUI

struct DealDetailView: View {
    let deal: Dealing
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?
    @State private var currentPrice: Double?
    @State private var ftseReturnPct: Double?
    @State private var priceBars: [PriceBar] = []
    @State private var priceDataReady = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    keyMetricsGrid

                    // Position card + chart: skeleton until all three fetches finish
                    if priceDataReady {
                        if let current = currentPrice {
                            PositionCard(
                                entryPence: deal.pricePence,
                                currentPence: current,
                                shares: deal.shares,
                                originalValue: deal.valueGbp,
                                ftseReturnPct: ftseReturnPct
                            )
                        }
                    } else {
                        SkeletonPositionCard()
                    }

                    if let analysis = deal.analysis {
                        if let checklist = analysis.checklist {
                            checklistSection(checklist)
                        }

                        if priceDataReady {
                            if !priceBars.isEmpty {
                                MiniPriceChart(
                                    ticker: deal.ticker,
                                    tradeDate: String(deal.tradeDate.prefix(10)),
                                    entryPricePence: deal.pricePence,
                                    bars: priceBars
                                )
                            }
                        } else {
                            SkeletonMiniPriceChart()
                        }

                        thesisSection(analysis)
                        evidenceSection(analysis)
                        keyRisksSection(analysis)
                    } else if let triage = deal.triage {
                        triageNotice(triage)
                    }
                    if let performance = deal.performance, !performance.isEmpty {
                        performanceSection(performance)
                    }
                    dealFieldsSection
                }
                .padding()
            }
            .background(colors.background)
            .navigationTitle(deal.ticker.replacingOccurrences(of: ".L", with: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.instrument(.medium, size: 16))
                        .foregroundStyle(colors.accent)
                }
            }
        }
        .task { await fetchPriceData() }
        .sheet(item: $selectedURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Ticker chip
                Text(deal.ticker.replacingOccurrences(of: ".L", with: ""))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(colors.border, lineWidth: 0.5)
                    )

                if let analysis = deal.analysis {
                    ratingBadge(analysis.rating)
                }

                Spacer()
            }

            Text(deal.displayCompany)
                .font(.instrument(.bold, size: 24))
                .foregroundStyle(colors.foreground)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Group {
            if let analysis = deal.analysis {
                Text(analysis.summary)
                    .font(.instrument(.semiBold, size: 17))
                    .foregroundStyle(colors.foreground.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Key Metrics Grid

    private var keyMetricsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            metricCell("Buyer", value: deal.director.name)
            metricCell("Role", value: deal.director.role)
            metricCell("Amount", value: formattedValue)
            if let analysis = deal.analysis {
                metricCell("Confidence", value: "\(Int(analysis.confidence * 100))%")
                metricCell("Catalyst", value: analysis.catalystWindow)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .overlay(
            VStack {
                Divider().overlay(colors.separator)
                Spacer()
                Divider().overlay(colors.separator)
            }
        )
    }

    private func metricCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(colors.muted)
            Text(value)
                .font(.instrument(.medium, size: 15))
                .foregroundStyle(colors.foreground)
                .lineLimit(1)
        }
    }

    // MARK: - Rating Checklist

    private func checklistSection(_ checklist: RatingChecklist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rating checklist")
                    .font(.instrument(.bold, size: 17))
                    .foregroundStyle(colors.foreground)
                Spacer()
                Text("\(checklist.passedCount) of \(RatingChecklist.labels.count) criteria met")
                    .font(.instrument(size: 13))
                    .foregroundStyle(colors.muted)
            }

            VStack(spacing: 0) {
                ForEach(Array(RatingChecklist.labels.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        let passed = checklist[keyPath: item.keyPath]
                        Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(passed ? Color.buyGreen : Color.sellRed)

                        Text(item.label)
                            .font(.instrument(size: 15))
                            .foregroundStyle(colors.foreground)

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if index < RatingChecklist.labels.count - 1 {
                        Divider().overlay(colors.separator)
                    }
                }
            }
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Thesis

    private func thesisSection(_ analysis: Analysis) -> some View {
        let paragraphs = ([analysis.summary] + analysis.thesisPoints)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Group {
            if !paragraphs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thesis")
                        .font(.instrument(.semiBold, size: 15))
                        .foregroundStyle(colors.foreground)

                    ThesisParagraphs(points: paragraphs)
                }
            }
        }
    }

    private struct ThesisParagraphs: View {
        let points: [String]
        @State private var expanded = false
        @Environment(\.ddbxColors) private var colors

        private let visibleLimit = 2

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                let visible = expanded ? points : Array(points.prefix(visibleLimit))
                ForEach(Array(visible.enumerated()), id: \.offset) { _, point in
                    Text(point)
                        .font(.instrument(size: 15))
                        .foregroundStyle(colors.foreground.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !expanded && points.count > visibleLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded = true }
                    } label: {
                        Text("…read more")
                            .font(.instrument(.semiBold, size: 14))
                            .foregroundStyle(colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Evidence

    private func evidenceSection(_ analysis: Analysis) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !analysis.evidenceFor.isEmpty {
                evidenceTable(
                    title: "Why this is interesting",
                    points: analysis.evidenceFor,
                    tone: .positive
                )
            }
            if !analysis.evidenceAgainst.isEmpty {
                evidenceTable(
                    title: "Why it might not be",
                    points: analysis.evidenceAgainst,
                    tone: .negative
                )
            }
        }
    }

    private enum EvidenceTone {
        case positive, negative

        var iconName: String {
            switch self {
            case .positive: "checkmark"
            case .negative: "xmark"
            }
        }

        var color: Color {
            switch self {
            case .positive: .buyGreen
            case .negative: .sellRed
            }
        }
    }

    private func evidenceTable(title: String, points: [EvidencePoint], tone: EvidenceTone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.instrument(.semiBold, size: 15))
                .foregroundStyle(colors.foreground)

            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tone.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tone.color)
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.headline)
                            .font(.instrument(.semiBold, size: 15))
                            .foregroundStyle(colors.foreground)

                        Text(point.detail)
                            .font(.instrument(size: 15))
                            .foregroundStyle(colors.foreground.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        if let urlString = point.sourceUrl, let url = URL(string: urlString) {
                            Button {
                                selectedURL = url
                            } label: {
                                HStack(spacing: 4) {
                                    Text(point.sourceLabel)
                                        .font(.instrument(size: 13))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(colors.accent)
                            }
                        } else {
                            Text(point.sourceLabel)
                                .font(.instrument(size: 13))
                                .foregroundStyle(colors.muted)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Key Risks

    private func keyRisksSection(_ analysis: Analysis) -> some View {
        Group {
            if !analysis.keyRisks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key risks")
                        .font(.instrument(.semiBold, size: 15))
                        .foregroundStyle(colors.foreground)

                    ForEach(analysis.keyRisks, id: \.self) { risk in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(Color.sellRed)
                            Text(risk)
                                .font(.instrument(size: 15))
                                .foregroundStyle(colors.foreground.opacity(0.9))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Triage notice

    private func triageNotice(_ triage: Triage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Verdict: \(triage.verdict.rawValue.capitalized)")
                    .font(.instrument(.semiBold, size: 15))
                    .foregroundStyle(colors.foreground)
                Text(triage.reason)
                    .font(.instrument(size: 15))
                    .foregroundStyle(colors.foreground.opacity(0.8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Performance

    private func performanceSection(_ rows: [PerformanceRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.instrument(.bold, size: 17))
                .foregroundStyle(colors.foreground)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(horizonLabel(row.horizonDays))
                        .font(.instrument(size: 15))
                        .foregroundStyle(colors.muted)
                    Spacer()
                    if let pct = row.returnPct {
                        Text(String(format: "%+.1f%%", pct))
                            .font(.instrument(.semiBold, size: 15))
                            .foregroundStyle(pct >= 0 ? Color.buyGreen : Color.sellRed)
                    } else {
                        Text("—")
                            .font(.instrument(size: 15))
                            .foregroundStyle(colors.muted)
                    }
                }
            }
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Deal fields (moved lower, matching web)

    private var dealFieldsSection: some View {
        VStack(spacing: 0) {
            fieldRow("Type", value: deal.txType == .buy ? "Buy" : "Sell",
                     color: deal.txType == .buy ? .buyGreen : .sellRed)
            Divider().overlay(colors.separator)
            fieldRow("Value", value: formattedValue)
            Divider().overlay(colors.separator)
            fieldRow("Shares", value: formatNumber(deal.shares))
            Divider().overlay(colors.separator)
            fieldRow("Price", value: String(format: "%.2fp", deal.pricePence))
            Divider().overlay(colors.separator)
            fieldRow("Trade Date", value: formatDate(deal.tradeDate))
            Divider().overlay(colors.separator)
            fieldRow("Disclosed", value: formatDate(deal.disclosedDate))
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    private func fieldRow(_ label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.instrument(size: 15))
                .foregroundStyle(colors.muted)
            Spacer()
            Text(value)
                .font(.instrument(.medium, size: 15))
                .foregroundStyle(color ?? colors.foreground)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Rating badge

    private func ratingBadge(_ rating: Rating) -> some View {
        Text(rating.rawValue.capitalized)
            .font(.instrument(.medium, size: 12))
            .foregroundStyle(ratingColor(rating))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ratingColor(rating).opacity(0.12), in: Capsule())
    }

    private func ratingColor(_ rating: Rating) -> Color {
        colors.ratingColor(rating)
    }

    // MARK: - Helpers

    private var formattedValue: String {
        let value = deal.valueGbp
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "£\(Int(value))"
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatDate(_ dateStr: String) -> String {
        guard let date = Self.isoParser.date(from: dateStr) else { return dateStr }
        return Self.displayFormatter.string(from: date)
    }

    private func horizonLabel(_ days: Int) -> String {
        switch days {
        case 90: "3 months"
        case 180: "6 months"
        case 365: "1 year"
        case 730: "2 years"
        default: "\(days) days"
        }
    }

    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // MARK: - Price data fetching

    private func fetchPriceData() async {
        async let pricesTask: () = fetchCurrentPrice()
        async let historyTask: () = fetchPriceHistory()
        async let ftseTask: () = fetchFtseReturn()
        _ = await (pricesTask, historyTask, ftseTask)
        priceDataReady = true
    }

    private func fetchCurrentPrice() async {
        do {
            let prices = try await APIClient.shared.latestPrices(tickers: [deal.ticker])
            if let price = prices.first {
                currentPrice = price.pricePence
            }
        } catch {
            // Silently fail — position card just won't show
        }
    }

    private func fetchPriceHistory() async {
        do {
            priceBars = try await APIClient.shared.priceHistory(ticker: deal.ticker)
        } catch {
            // Silently fail — chart just won't show
        }
    }

    private func fetchFtseReturn() async {
        do {
            let tradeDate = String(deal.tradeDate.prefix(10))
            guard let ftseEntry = try await APIClient.shared.priceOn(ticker: "^FTAS", date: tradeDate) else { return }
            let ftseLatest = try await APIClient.shared.latestPrices(tickers: ["^FTAS"])
            guard let ftseCurrent = ftseLatest.first?.pricePence else { return }
            ftseReturnPct = (ftseCurrent - ftseEntry) / ftseEntry
        } catch {
            // Silently fail
        }
    }
}
