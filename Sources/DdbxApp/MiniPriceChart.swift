import SwiftUI

struct MiniPriceChart: View {
    let ticker: String
    let tradeDate: String
    let entryPricePence: Double
    let bars: [PriceBar]

    @Environment(\.ddbxColors) private var colors
    @State private var period: Period = .since

    enum Period: String, CaseIterable {
        case since = "Since entry"
        case ytd = "YTD"
        case max = "Max"
    }

    private var visibleBars: [PriceBar] {
        switch period {
        case .since:
            return bars.filter { $0.date >= tradeDate }
        case .ytd:
            let year = String(Calendar.current.component(.year, from: Date()))
            return bars.filter { $0.date >= "\(year)-01-01" }
        case .max:
            return bars
        }
    }

    private var lastClose: Double? { visibleBars.last?.closePence }
    private var returnPct: Double? {
        guard let last = lastClose else { return nil }
        return ((last - entryPricePence) / entryPricePence) * 100
    }
    private var up: Bool { (returnPct ?? 0) >= 0 }
    private var lineColor: Color { up ? .buyGreen : .sellRed }

    private var periodHigh: Double { visibleBars.map(\.closePence).max() ?? 0 }
    private var periodLow: Double { visibleBars.map(\.closePence).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(ticker.replacingOccurrences(of: ".L", with: ""))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.foreground)

                Spacer()

                if let pct = returnPct {
                    Text(String(format: "%+.1f%%", pct))
                        .font(.instrument(.semiBold, size: 14))
                        .foregroundStyle(lineColor)
                }
            }

            // Period toggles
            HStack(spacing: 4) {
                ForEach(Period.allCases, id: \.self) { p in
                    Button(p.rawValue) {
                        withAnimation(.easeInOut(duration: 0.2)) { period = p }
                    }
                    .font(.instrument(.medium, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(period == p ? colors.accent.opacity(0.15) : .clear, in: Capsule())
                    .foregroundStyle(period == p ? colors.accent : colors.muted)
                }
                Spacer()
            }

            // Chart
            if visibleBars.count >= 2 {
                chartView
                    .frame(height: 120)
            } else {
                Text("Not enough data")
                    .font(.instrument(size: 13))
                    .foregroundStyle(colors.muted)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }

            // Price legend
            HStack(spacing: 12) {
                legendItem("Entry", value: String(format: "%.0fp", entryPricePence))
                if let last = lastClose {
                    legendItem("Now", value: String(format: "%.0fp", last))
                }
                Spacer()
                legendItem("Low", value: String(format: "%.0fp", periodLow))
                legendItem("High", value: String(format: "%.0fp", periodHigh))
            }
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    private func legendItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(colors.muted)
            Text(value)
                .font(.instrument(.medium, size: 12))
                .foregroundStyle(colors.foreground)
        }
    }

    // MARK: - Chart drawing

    private var chartView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let prices = visibleBars.map(\.closePence)
            let minP = prices.min() ?? 0
            let maxP = prices.max() ?? 1
            let yPad = max((maxP - minP) * 0.06, 5)
            let yMin = minP - yPad
            let yMax = maxP + yPad
            let yRange = yMax - yMin
            let n = prices.count

            Canvas { context, size in
                // Entry price dashed line
                let entryY = h * (1 - (entryPricePence - yMin) / yRange)
                if entryY > 0 && entryY < h {
                    var entryPath = Path()
                    entryPath.move(to: CGPoint(x: 0, y: entryY))
                    entryPath.addLine(to: CGPoint(x: w, y: entryY))
                    context.stroke(
                        entryPath,
                        with: .color(colors.muted.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }

                // Entry date vertical line (if not "since")
                if period != .since {
                    if let entryIdx = visibleBars.firstIndex(where: { $0.date >= tradeDate }) {
                        let entryX = w * CGFloat(entryIdx) / CGFloat(n - 1)
                        var vPath = Path()
                        vPath.move(to: CGPoint(x: entryX, y: 0))
                        vPath.addLine(to: CGPoint(x: entryX, y: h))
                        context.stroke(
                            vPath,
                            with: .color(colors.muted.opacity(0.25)),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    }
                }

                // Price line
                guard n >= 2 else { return }
                var path = Path()
                for (i, price) in prices.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(n - 1)
                    let y = h * (1 - (price - yMin) / yRange)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(lineColor), lineWidth: 1.5)

                // Entry dot
                if let entryIdx = visibleBars.firstIndex(where: { $0.date >= tradeDate }) {
                    let ex = w * CGFloat(entryIdx) / CGFloat(n - 1)
                    let ey = h * (1 - (prices[entryIdx] - yMin) / yRange)
                    context.fill(
                        Circle().path(in: CGRect(x: ex - 3, y: ey - 3, width: 6, height: 6)),
                        with: .color(lineColor.opacity(0.55))
                    )
                }

                // Latest dot
                let lastX = w
                let lastY = h * (1 - (prices[n - 1] - yMin) / yRange)
                context.fill(
                    Circle().path(in: CGRect(x: lastX - 3, y: lastY - 3, width: 6, height: 6)),
                    with: .color(lineColor)
                )
            }
        }
    }
}
