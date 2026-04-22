import SwiftUI

struct PerformanceChart: View {
    let strategy: [PortfolioPoint]
    let benchmark: [PortfolioPoint]
    let deployed: [PortfolioPoint]
    let viewMode: PerformanceViewMode

    @Environment(\.ddbxColors) private var colors
    @State private var scrubIndex: Int?

    private var n: Int {
        [strategy.count, benchmark.count, deployed.count].min() ?? 0
    }

    /// Return % at each timeline index, based on cumulative deployed at
    /// that point. Produces a meaningful curve from the first £ deployed
    /// through to today.
    private var strategyPct: [Double] {
        (0..<n).map { i in
            let d = deployed[i].value
            return d > 0 ? (strategy[i].value - d) / d : 0
        }
    }

    private var benchmarkPct: [Double] {
        (0..<n).map { i in
            let d = deployed[i].value
            return d > 0 ? (benchmark[i].value - d) / d : 0
        }
    }

    private var alphaPct: [Double] {
        (0..<n).map { strategyPct[$0] - benchmarkPct[$0] }
    }

    private let yAxisInset: CGFloat = 36
    private let chartHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if n >= 2 {
                chartBody
                    .frame(height: chartHeight)
                axisDateLabels
            } else {
                placeholder
                    .frame(height: chartHeight)
            }
            legend
        }
        .padding(14)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if let i = scrubIndex, i < n {
            scrubHeader(index: i)
        } else {
            idleHeader
        }
    }

    private var idleHeader: some View {
        HStack(spacing: 8) {
            if viewMode == .realTerms {
                legendBadge(color: colors.accent, label: "Picks", value: formatPct(strategyPct.last ?? 0))
                Spacer()
                legendBadge(color: colors.muted, label: "Benchmark", value: formatPct(benchmarkPct.last ?? 0))
            } else {
                let a = alphaPct.last ?? 0
                legendBadge(
                    color: a >= 0 ? Color.buyGreen : Color.sellRed,
                    label: "vs Benchmark",
                    value: formatPp(a)
                )
                Spacer()
            }
        }
    }

    private func scrubHeader(index i: Int) -> some View {
        HStack(spacing: 10) {
            Text(formatShortDate(strategy[i].date))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(colors.foreground)
            if viewMode == .realTerms {
                Text("Picks").font(.instrument(.medium, size: 11)).foregroundStyle(colors.accent)
                Text(formatPct(strategyPct[i]))
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(colors.foreground)
                Text("Benchmark").font(.instrument(.medium, size: 11)).foregroundStyle(colors.muted)
                Text(formatPct(benchmarkPct[i]))
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(colors.foreground)
            } else {
                let a = alphaPct[i]
                Text(formatPp(a))
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(a >= 0 ? Color.buyGreen : Color.sellRed)
            }
            Spacer()
        }
    }

    private func legendBadge(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.instrument(.medium, size: 11)).foregroundStyle(colors.muted)
            Text(value).font(.instrument(.semiBold, size: 13)).foregroundStyle(colors.foreground)
        }
    }

    // MARK: - Chart body

    private var chartBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let canvasLeft = yAxisInset

            ZStack(alignment: .topLeading) {
                // Y-axis labels + gridlines painted in a single Canvas for alignment.
                Canvas { ctx, _ in
                    switch viewMode {
                    case .realTerms:
                        drawRealTerms(ctx: ctx, w: w, h: h, canvasLeft: canvasLeft)
                    case .vsMarket:
                        drawAlpha(ctx: ctx, w: w, h: h, canvasLeft: canvasLeft)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(chartLeft: canvasLeft, chartWidth: w - canvasLeft))
        }
    }

    private func scrubGesture(chartLeft: CGFloat, chartWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard chartWidth > 0, n >= 2 else { return }
                let x = max(0, min(chartWidth, value.location.x - chartLeft))
                let ratio = x / chartWidth
                let idx = min(n - 1, max(0, Int((ratio * CGFloat(n - 1)).rounded())))
                if scrubIndex != idx { scrubIndex = idx }
            }
            .onEnded { _ in
                scrubIndex = nil
            }
    }

    // MARK: - Drawing

    private func drawRealTerms(ctx: GraphicsContext, w: CGFloat, h: CGFloat, canvasLeft: CGFloat) {
        let values = strategyPct + benchmarkPct
        let (yMin, yMax, ticks) = bounds(for: values, includeZero: true)
        let yRange = max(yMax - yMin, 1e-6)
        let chartW = w - canvasLeft

        func yFor(_ v: Double) -> CGFloat {
            h * (1 - CGFloat((v - yMin) / yRange))
        }

        drawGridAndLabels(ctx: ctx, ticks: ticks, yMin: yMin, yMax: yMax, w: w, h: h, canvasLeft: canvasLeft)

        // Benchmark (dashed, muted)
        stroke(ctx: ctx, values: benchmarkPct, w: chartW, h: h,
               xOffset: canvasLeft, yFor: yFor,
               color: colors.muted.opacity(0.85),
               style: StrokeStyle(lineWidth: 1.25, dash: [3, 3]))

        // Strategy (solid accent)
        stroke(ctx: ctx, values: strategyPct, w: chartW, h: h,
               xOffset: canvasLeft, yFor: yFor,
               color: colors.accent,
               style: StrokeStyle(lineWidth: 1.75))

        // Terminal dots
        let lastI = n - 1
        let lastX = canvasLeft + chartW
        ctx.fill(
            Circle().path(in: CGRect(x: lastX - 3.5, y: yFor(strategyPct[lastI]) - 3.5, width: 7, height: 7)),
            with: .color(colors.accent)
        )
        ctx.fill(
            Circle().path(in: CGRect(x: lastX - 3, y: yFor(benchmarkPct[lastI]) - 3, width: 6, height: 6)),
            with: .color(colors.muted)
        )

        if let i = scrubIndex, i < n {
            drawScrubMarker(ctx: ctx, index: i, w: chartW, h: h,
                            xOffset: canvasLeft, yFor: yFor,
                            points: [(strategyPct[i], colors.accent),
                                     (benchmarkPct[i], colors.muted)])
        }
    }

    private func drawAlpha(ctx: GraphicsContext, w: CGFloat, h: CGFloat, canvasLeft: CGFloat) {
        let (yMin, yMax, ticks) = bounds(for: alphaPct, includeZero: true)
        let yRange = max(yMax - yMin, 1e-6)
        let chartW = w - canvasLeft

        func yFor(_ v: Double) -> CGFloat {
            h * (1 - CGFloat((v - yMin) / yRange))
        }

        drawGridAndLabels(ctx: ctx, ticks: ticks, yMin: yMin, yMax: yMax, w: w, h: h, canvasLeft: canvasLeft, labelSuffix: "pp")

        // Zero line (bolder than other gridlines)
        if yMin <= 0 && yMax >= 0 {
            let zeroY = yFor(0)
            var path = Path()
            path.move(to: CGPoint(x: canvasLeft, y: zeroY))
            path.addLine(to: CGPoint(x: w, y: zeroY))
            ctx.stroke(path, with: .color(colors.muted.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // Signed fill + line
        let end = alphaPct.last ?? 0
        let lineColor: Color = end >= 0 ? .buyGreen : .sellRed

        // Fill area between line and zero
        var fillPath = Path()
        let zeroY = yFor(0)
        fillPath.move(to: CGPoint(x: canvasLeft, y: zeroY))
        for i in 0..<n {
            let x = canvasLeft + chartW * CGFloat(i) / CGFloat(n - 1)
            fillPath.addLine(to: CGPoint(x: x, y: yFor(alphaPct[i])))
        }
        fillPath.addLine(to: CGPoint(x: canvasLeft + chartW, y: zeroY))
        fillPath.closeSubpath()
        ctx.fill(fillPath, with: .color(lineColor.opacity(0.18)))

        // Line itself
        stroke(ctx: ctx, values: alphaPct, w: chartW, h: h,
               xOffset: canvasLeft, yFor: yFor,
               color: lineColor,
               style: StrokeStyle(lineWidth: 1.75))

        let lastX = canvasLeft + chartW
        ctx.fill(
            Circle().path(in: CGRect(x: lastX - 3.5, y: yFor(alphaPct[n - 1]) - 3.5, width: 7, height: 7)),
            with: .color(lineColor)
        )

        if let i = scrubIndex, i < n {
            drawScrubMarker(ctx: ctx, index: i, w: chartW, h: h,
                            xOffset: canvasLeft, yFor: yFor,
                            points: [(alphaPct[i], lineColor)])
        }
    }

    // MARK: - Shared drawing helpers

    private func stroke(
        ctx: GraphicsContext,
        values: [Double],
        w: CGFloat,
        h: CGFloat,
        xOffset: CGFloat,
        yFor: (Double) -> CGFloat,
        color: Color,
        style: StrokeStyle
    ) {
        var path = Path()
        for i in 0..<values.count {
            let x = xOffset + w * CGFloat(i) / CGFloat(max(values.count - 1, 1))
            let y = yFor(values[i])
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(color), style: style)
    }

    private func drawGridAndLabels(
        ctx: GraphicsContext,
        ticks: [Double],
        yMin: Double,
        yMax: Double,
        w: CGFloat,
        h: CGFloat,
        canvasLeft: CGFloat,
        labelSuffix: String = "%"
    ) {
        let yRange = max(yMax - yMin, 1e-6)
        for tick in ticks {
            let y = h * (1 - CGFloat((tick - yMin) / yRange))
            var grid = Path()
            grid.move(to: CGPoint(x: canvasLeft, y: y))
            grid.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(grid, with: .color(colors.muted.opacity(0.15)), lineWidth: 0.5)

            let text = Text(formatTick(tick, suffix: labelSuffix))
                .font(.system(size: 10, weight: .medium))
            var resolved = ctx.resolve(text)
            resolved.shading = .color(colors.muted)
            let size = resolved.measure(in: CGSize(width: canvasLeft, height: h))
            let labelX = max(0, canvasLeft - size.width - 4)
            let labelY = min(h - size.height, max(0, y - size.height / 2))
            ctx.draw(resolved, at: CGPoint(x: labelX, y: labelY), anchor: .topLeading)
        }
    }

    private func drawScrubMarker(
        ctx: GraphicsContext,
        index i: Int,
        w: CGFloat,
        h: CGFloat,
        xOffset: CGFloat,
        yFor: (Double) -> CGFloat,
        points: [(value: Double, color: Color)]
    ) {
        let x = xOffset + w * CGFloat(i) / CGFloat(max(n - 1, 1))

        // Vertical tracking line
        var v = Path()
        v.move(to: CGPoint(x: x, y: 0))
        v.addLine(to: CGPoint(x: x, y: h))
        ctx.stroke(v, with: .color(colors.muted.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

        // Dots at each series
        for (value, color) in points {
            let y = yFor(value)
            ctx.fill(
                Circle().path(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                with: .color(colors.surface)
            )
            ctx.fill(
                Circle().path(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                with: .color(color)
            )
        }
    }

    // MARK: - Bounds & ticks

    /// Returns (yMin, yMax, ticks) chosen to produce ~5 round % tick marks.
    private func bounds(for values: [Double], includeZero: Bool) -> (Double, Double, [Double]) {
        guard !values.isEmpty, let lo = values.min(), let hi = values.max() else {
            return (0, 0.01, [0])
        }
        var vMin = lo, vMax = hi
        if includeZero {
            vMin = min(vMin, 0)
            vMax = max(vMax, 0)
        }
        let rawRange = max(vMax - vMin, 0.01)
        let padded = rawRange * 0.12
        let yMin = vMin - padded
        let yMax = vMax + padded
        let ticks = niceTicks(min: yMin, max: yMax, target: 5)
        return (yMin, yMax, ticks)
    }

    /// Pick ~target "nice" tick positions (at 1/2/5/10 multiples of a power of 10)
    /// in percent space. Assumes input values are in decimal (0.042 == 4.2%).
    private func niceTicks(min yMin: Double, max yMax: Double, target: Int) -> [Double] {
        let span = yMax - yMin
        guard span > 0 else { return [yMin] }
        let roughStep = span / Double(target)
        let mag = pow(10, floor(log10(roughStep)))
        let norm = roughStep / mag
        let step: Double
        if norm < 1.5 { step = mag }
        else if norm < 3 { step = 2 * mag }
        else if norm < 7 { step = 5 * mag }
        else { step = 10 * mag }

        let first = (yMin / step).rounded(.up) * step
        var out: [Double] = []
        var v = first
        while v <= yMax + step * 0.001 {
            out.append(v)
            v += step
        }
        return out
    }

    // MARK: - Axis / legend / placeholder

    private var axisDateLabels: some View {
        HStack {
            Spacer().frame(width: yAxisInset)
            Text(formatShortDate(strategy.first?.date ?? ""))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(colors.muted)
            Spacer()
            Text(formatShortDate(strategy.last?.date ?? ""))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(colors.muted)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            if viewMode == .realTerms {
                legendDot(color: colors.accent, text: "Picks")
                legendDot(color: colors.muted, text: "Benchmark")
            } else {
                let a = alphaPct.last ?? 0
                legendDot(color: a >= 0 ? .buyGreen : .sellRed, text: "Picks − Benchmark")
            }
            Spacer()
            Text("Tap & drag to scrub")
                .font(.instrument(size: 10))
                .foregroundStyle(colors.muted.opacity(0.7))
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.instrument(size: 11))
                .foregroundStyle(colors.muted)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 22))
                .foregroundStyle(colors.muted.opacity(0.5))
            Text("Not enough data")
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    private func formatPct(_ value: Double) -> String {
        let p = value * 100
        let sign = p >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(p)))%"
    }

    private func formatPp(_ value: Double) -> String {
        let p = value * 100
        let sign = p >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(p)))pp"
    }

    private func formatTick(_ value: Double, suffix: String) -> String {
        let p = value * 100
        // Drop decimal if it's a whole number at this step
        if abs(p - p.rounded()) < 0.05 {
            return "\(Int(p.rounded()))\(suffix)"
        }
        return "\(String(format: "%.1f", p))\(suffix)"
    }

    private func formatShortDate(_ isoDate: String) -> String {
        guard isoDate.count >= 10 else { return isoDate }
        let d = String(isoDate.prefix(10))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        guard let date = f.date(from: d) else { return d }
        let out = DateFormatter()
        out.dateFormat = "d MMM"
        out.timeZone = TimeZone(identifier: "Europe/London")
        return out.string(from: date)
    }
}
