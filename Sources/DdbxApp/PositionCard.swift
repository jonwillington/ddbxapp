import SwiftUI

struct PositionCard: View {
    let entryPence: Double
    let currentPence: Double
    let shares: Int
    let originalValue: Double
    let ftseReturnPct: Double?

    @Environment(\.ddbxColors) private var colors

    private var stockPct: Double { (currentPence - entryPence) / entryPence }
    private var up: Bool { stockPct >= 0 }
    private var currentValue: Double { (Double(shares) * currentPence) / 100.0 }
    private var gainLoss: Double { currentValue - originalValue }
    private var alphaPct: Double? {
        guard let ftse = ftseReturnPct else { return nil }
        return stockPct - ftse
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            cell(
                label: "Entry",
                main: formatPence(entryPence),
                sub: formatGbp(originalValue),
                color: colors.foreground
            )
            cell(
                label: "Now",
                main: formatPence(currentPence),
                sub: formatGbp(currentValue),
                color: up ? .buyGreen : .sellRed
            )
            cell(
                label: "Performance",
                main: String(format: "%+.1f%%", stockPct * 100),
                sub: String(format: "%@%@", gainLoss >= 0 ? "+" : "", formatGbp(abs(gainLoss))),
                color: up ? .buyGreen : .sellRed,
                filled: true
            )
            if let alpha = alphaPct {
                let ahead = alpha >= 0
                cell(
                    label: "vs FTSE",
                    main: ahead ? "Outperformed" : "Underperformed",
                    sub: "vs FTSE All-Share",
                    color: ahead ? .buyGreen : .sellRed
                )
            }
        }
    }

    private func cell(label: String, main: String, sub: String, color: Color, filled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(filled ? .white.opacity(0.7) : colors.muted)

            Text(main)
                .font(.instrument(.bold, size: 18))
                .foregroundStyle(filled ? .white : color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if !sub.isEmpty {
                Text(sub)
                    .font(.instrument(size: 12))
                    .foregroundStyle(filled ? .white.opacity(0.7) : colors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            filled ? AnyShapeStyle(color) : AnyShapeStyle(colors.surface),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(filled ? .clear : colors.border, lineWidth: 0.5)
        )
    }

    private func formatPence(_ p: Double) -> String {
        if p >= 10 { return String(format: "%.1fp", p) }
        if p >= 1  { return String(format: "%.2fp", p) }
        return String(format: "%.3fp", p)
    }

    private func formatGbp(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: v)) ?? "£\(Int(v))"
    }
}
