import SwiftUI

struct DealRow: View {
    let deal: Dealing
    /// Return % since entry — drives both the metrics line and (in lift-sort) the trailing.
    var liftPct: Double? = nil
    /// FTSE All-Share return since the deal's entry date (for alpha metrics).
    var ftsePct: Double? = nil
    /// Set in lift-sort mode: date on the left, % in the trailing accessory.
    var leadingDateLabel: String? = nil

    @Environment(\.ddbxColors) private var colors
    @EnvironmentObject private var settings: AppSettings

    // Lift-sort mode is indicated by leadingDateLabel being set.
    private var isLiftSort: Bool { leadingDateLabel != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left: suggestion icon
            suggestionIcon

            // Center: company, ticker · director, rating
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.displayCompany)
                    .font(.instrument(.semiBold, size: 15))
                    .foregroundStyle(colors.foreground)
                    .lineLimit(1)

                directorLine

                if let analysis = deal.analysis {
                    HStack(spacing: 6) {
                        ratingBadge(analysis.rating)
                        if let checklist = analysis.checklist {
                            Text("\(checklist.passedCount)/6 criteria")
                                .font(.instrument(size: 11))
                                .foregroundStyle(colors.muted)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            // Right column: value + performance
            VStack(alignment: .trailing, spacing: 4) {
                metricValue
                metricsLine
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let txLabel = deal.txType == .buy ? "Buy" : "Sell"
        var desc = "\(deal.ticker.replacingOccurrences(of: ".L", with: "")), \(deal.displayCompany), \(deal.director.name), \(txLabel), \(formattedValue)"
        if let rating = deal.analysis?.rating {
            desc += ", rated \(rating.rawValue)"
        }
        desc += deal.isSuggested ? ", suggested" : ", skipped"
        return desc
    }

    // MARK: - Director line

    private var directorLine: some View {
        HStack(spacing: 0) {
            Text(deal.ticker.replacingOccurrences(of: ".L", with: ""))
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
            Text(" · ")
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
            if let timeStr = ingestionTime {
                Text(timeStr)
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(colors.muted)
                Text(" · ")
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(colors.muted)
            }
            Text(deal.director.name)
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
                .lineLimit(1)
        }
    }

    /// Returns `"HH:mm"` (UK time) if this deal was ingested today during market hours (08:00–16:35), else nil.
    private var ingestionTime: String? {
        guard let raw = deal.createdAt else { return nil }
        guard let date = Self.createdAtParser.date(from: raw) else { return nil }
        let todayStr = Self.ukDateOnly.string(from: Date())
        let dealDayStr = Self.ukDateOnly.string(from: date)
        guard dealDayStr == todayStr else { return nil }
        let timeStr = Self.ukTimeFormatter.string(from: date)
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        let totalMinutes = hour * 60 + minute
        guard totalMinutes >= 8 * 60 && totalMinutes <= 16 * 60 + 35 else { return nil }
        return timeStr
    }

    // MARK: - Metrics line (trend icon · return % · market verdict)

    @ViewBuilder
    private var metricsLine: some View {
        let effective: ValueColumnMetric = isLiftSort ? .dealSize : settings.valueColumnMetric
        if let pct = liftPct, effective != .returnPct {
            let up = pct >= 0
            let trendColor: Color = up ? .buyGreen : .sellRed
            HStack(spacing: 3) {
                Image(systemName: up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(trendColor)
                Text(String(format: "%+.1f%%", pct * 100))
                    .font(.instrument(size: 11))
                    .foregroundStyle(trendColor)
                if let stock = liftPct, let ftse = ftsePct {
                    Text("·")
                        .font(.instrument(size: 11))
                        .foregroundStyle(colors.muted)
                    Text(stock > ftse ? "beat market" : "below market")
                        .font(.instrument(size: 11))
                        .foregroundStyle(colors.muted)
                }
            }
        } else if deal.pricePence > 0 {
            Text(formatPence(deal.pricePence))
                .font(.instrument(size: 11))
                .foregroundStyle(colors.muted)
        }
    }

    // MARK: - Metric value column

    @ViewBuilder
    private var metricValue: some View {
        let effective: ValueColumnMetric = isLiftSort ? .dealSize : settings.valueColumnMetric
        switch effective {
        case .dealSize:
            Text(formattedValue)
                .font(.instrument(.semiBold, size: 17))
                .foregroundStyle(colors.foreground)
        case .returnPct:
            if let pct = liftPct {
                Text(String(format: "%+.1f%%", pct * 100))
                    .font(.instrument(.semiBold, size: 17))
                    .foregroundStyle(pct >= 0 ? Color.buyGreen : Color.sellRed)
            } else {
                Text("—").font(.instrument(.semiBold, size: 17)).foregroundStyle(colors.muted)
            }
        case .currentPrice:
            if let pct = liftPct, deal.pricePence > 0 {
                Text(formatPence(deal.pricePence * (1 + pct)))
                    .font(.instrument(.semiBold, size: 17))
                    .foregroundStyle(colors.foreground)
            } else {
                Text("—").font(.instrument(.semiBold, size: 17)).foregroundStyle(colors.muted)
            }
        case .outperformLabel:
            if let stock = liftPct, let ftse = ftsePct {
                let ahead = stock > ftse
                Text(ahead ? "Outperformed" : "Underperformed")
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(ahead ? Color.buyGreen : Color.sellRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—").font(.instrument(.semiBold, size: 17)).foregroundStyle(colors.muted)
            }
        case .returnVsFtse:
            if let stock = liftPct, let ftse = ftsePct {
                let alpha = stock - ftse
                Text(String(format: "%+.1fpp", alpha * 100))
                    .font(.instrument(.semiBold, size: 17))
                    .foregroundStyle(alpha >= 0 ? Color.buyGreen : Color.sellRed)
            } else {
                Text("—").font(.instrument(.semiBold, size: 17)).foregroundStyle(colors.muted)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var suggestionIcon: some View {
        if deal.isSuggested {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colors.accent)
        } else {
            Image(systemName: "xmark.circle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(colors.muted)
        }
    }

    private func ratingBadge(_ rating: Rating) -> some View {
        Text(rating.rawValue.capitalized)
            .font(.instrument(.medium, size: 11))
            .foregroundStyle(colors.ratingColor(rating))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colors.ratingColor(rating).opacity(0.12), in: Capsule())
    }

    private func formatPence(_ p: Double) -> String {
        if p >= 10 { return String(format: "%.1fp", p) }
        if p >= 1  { return String(format: "%.2fp", p) }
        return String(format: "%.3fp", p)
    }

    private var formattedValue: String {
        let value = deal.valueGbp
        if value >= 1_000_000 {
            return String(format: "£%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "£%.0fK", value / 1_000)
        } else {
            return String(format: "£%.0f", value)
        }
    }

    // MARK: - Formatters

    private static let createdAtParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let ukDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private static let ukTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()
}
