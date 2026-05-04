import SwiftUI

/// Drill-down sheet shown when the user taps a sector row on the
/// "By Industry" leaderboard. Reuses `PerformanceChart` directly with the
/// sector's pre-computed `PerformanceResult`, plus a header summarising the
/// alpha and a list of contributors restricted to that sector.
struct SectorDrilldownSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let sector: SectorNormalized
    let result: PerformanceResult
    let benchmarkName: String
    let viewMode: PerformanceViewMode

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        chart
                        contributors
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(sector.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.instrument(.semiBold, size: 14))
                        .foregroundStyle(colors.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                stat(label: "Picks",
                     value: formatPct(result.strategyReturnPct),
                     tint: result.strategyReturnPct >= 0 ? .buyGreen : .sellRed)
                stat(label: benchmarkName,
                     value: formatPct(result.benchmarkReturnPct),
                     tint: result.benchmarkReturnPct >= 0 ? .buyGreen : .sellRed)
                stat(label: "Alpha",
                     value: formatPp(result.alphaReturnPct * 100),
                     tint: result.alphaReturnPct >= 0 ? .buyGreen : .sellRed)
            }
            Text("\(result.dealCount) \(result.dealCount == 1 ? "deal" : "deals") in this sector — \(formatGbpCompact(result.totalDeployed)) deployed")
                .font(.instrument(size: 12))
                .foregroundStyle(colors.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    private func stat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(colors.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.instrument(.bold, size: 20))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chart: some View {
        if result.strategy.count >= 2 {
            PerformanceChart(
                strategy: result.strategy,
                benchmark: result.benchmark,
                deployed: result.deployed,
                viewMode: viewMode,
                entryDates: result.contributors.map(\.entryDate)
            )
        } else {
            Text("Not enough data to render a chart for this sector.")
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(colors.border, lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    private var contributors: some View {
        if !result.contributors.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Contributors")
                    .font(.instrument(.semiBold, size: 16))
                    .foregroundStyle(colors.foreground)
                    .padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(result.contributors) { row in
                        contributorRow(row)
                        if row.id != result.contributors.last?.id {
                            Divider()
                                .overlay(colors.separator)
                                .padding(.leading, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(colors.border, lineWidth: 0.5)
                )
            }
        }
    }

    private func contributorRow(_ row: ContributorRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.ticker.replacingOccurrences(of: ".L", with: ""))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colors.foreground)
                    .lineLimit(1)
                Text(row.company)
                    .font(.instrument(size: 12))
                    .foregroundStyle(colors.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPct(row.returnPct))
                    .font(.instrument(.semiBold, size: 13))
                    .foregroundStyle(row.returnPct >= 0 ? Color.buyGreen : Color.sellRed)
                    .lineLimit(1)
                    .fixedSize()
                Text(formatSignedGbp(row.pnl))
                    .font(.instrument(size: 11))
                    .foregroundStyle(colors.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Formatting

    private func formatPct(_ value: Double) -> String {
        let pct = value * 100
        let sign = pct >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(pct)))%"
    }

    private func formatPp(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(value)))pp"
    }

    private func formatSignedGbp(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        let abs = Swift.abs(value)
        if abs >= 10_000 {
            return "\(sign)£\(String(format: "%.1f", abs / 1_000))k"
        }
        return "\(sign)£\(String(format: "%.0f", abs))"
    }

    private func formatGbpCompact(_ value: Double) -> String {
        if value >= 10_000 {
            return "£\(String(format: "%.1f", value / 1_000))k"
        }
        return "£\(String(format: "%.0f", value))"
    }
}
