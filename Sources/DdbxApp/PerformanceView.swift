import SwiftUI

struct PerformanceView: View {
    @Environment(\.ddbxColors) private var colors
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pushManager: PushManager
    @EnvironmentObject private var vm: DashboardViewModel
    @StateObject private var perfVM = PerformanceViewModel()
    @State private var selectedDeal: Dealing?
    @State private var activeCriterion: ActiveCriterion?
    @State private var activeMetric: PerformanceMetricKind?
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var showNotifications = false

    enum ActiveCriterion: Identifiable {
        case universe, window, exit, benchmark, amount
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LogoButton(showAbout: $showAbout)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showNotifications = true } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(colors.foreground)
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(colors.foreground)
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                PaywallView(showsClose: true)
            }
            .sheet(isPresented: $showSettings) {
                AppSettingsSheet()
                    .environmentObject(settings)
                    .environmentObject(pushManager)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet()
                    .environmentObject(pushManager)
            }
            .sheet(item: $selectedDeal) { deal in
                DealDetailView(deal: deal)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $activeCriterion) { criterion in
                criteriaSheet(for: criterion)
            }
            .sheet(item: $activeMetric) { kind in
                PerformanceMetricSheet(kind: kind, config: perfVM.config)
            }
        }
        .task {
            vm.startPolling()
            perfVM.benchmarkChanged(to: settings.marketBenchmark)
            // apply(deals:) is covered by .onReceive below — calling it here
            // too causes a redundant recompute cycle on first appear.
        }
        .onReceive(vm.$dealings) { deals in
            perfVM.apply(deals: deals)
        }
        .onChange(of: settings.marketBenchmark) { newValue in
            perfVM.benchmarkChanged(to: newValue)
        }
        .onChange(of: perfVM.config) { _ in
            perfVM.configChanged()
        }
    }

    // MARK: - Layout

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title
                heroCard
                viewModeSegmented
                chartSection
                contributorsSection
            }
            .padding(.bottom, 32)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    private var title: some View {
        HStack {
            Text("Performance")
                .font(.instrument(.bold, size: 28))
                .foregroundStyle(colors.foreground)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if showHeroSkeleton {
                    heroSkeletonRow
                } else if perfVM.result.totalDeployed > 0 {
                    HStack(alignment: .top, spacing: 12) {
                        Button { activeMetric = .picks } label: {
                            heroStat(label: "Picks",
                                     value: heroPicksValue,
                                     tint: heroPicksTint,
                                     alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button { activeMetric = .benchmark(name: settings.marketBenchmark.displayName) } label: {
                            heroStat(label: settings.marketBenchmark.displayName,
                                     value: heroBenchValue,
                                     tint: heroBenchTint,
                                     alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // else: filter returned zero deals — numbers hidden;
                // the strategy sentence below explains why.
            }
            .animation(recomputeAnimation, value: showHeroSkeleton)
            criteriaGrid
            VStack(alignment: .leading, spacing: 4) {
                Text(strategySentence)
                    .font(.instrument(size: 13))
                    .foregroundStyle(colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if perfVM.result.excludedForDataCount > 0 {
                    Text("\(perfVM.result.excludedForDataCount) excluded — no price data")
                        .font(.instrument(size: 11))
                        .foregroundStyle(colors.muted)
                }
                if let error = perfVM.error {
                    Text(error)
                        .font(.instrument(size: 11))
                        .foregroundStyle(Color.sellRed)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// First-load skeleton: no result yet AND something is in flight.
    /// Distinct from "filter matched zero deals", which is a stable empty
    /// state (handled separately — numbers simply aren't rendered).
    private var isFirstLoad: Bool {
        guard perfVM.result.totalDeployed == 0 else { return false }
        return vm.dealings.isEmpty || perfVM.isComputing
    }

    /// Shimmer the hero numbers whenever a compute is in flight — even if
    /// prior numbers exist — so knob changes read as a clear transition
    /// instead of an instant swap. Combined with the VM's minimum visible
    /// compute duration (`minVisibleComputeDuration`), this guarantees the
    /// shimmer is visible long enough to notice.
    private var showHeroSkeleton: Bool {
        isFirstLoad || perfVM.isComputing
    }

    private var heroSkeletonRow: some View {
        HStack(alignment: .top, spacing: 12) {
            heroSkeletonColumn(label: "Picks", alignment: .leading)
            heroSkeletonColumn(label: settings.marketBenchmark.displayName,
                               alignment: .trailing)
        }
    }

    /// Skeleton column that reserves the *exact* rendered-text bounds by
    /// using an invisible stand-in `Text` in the same font as the real
    /// numbers, then overlaying a rounded rectangle that shimmers. Real
    /// labels (PICKS / BENCHMARK) stay solid — they don't change.
    private func heroSkeletonColumn(label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(colors.muted)
            ZStack {
                // Invisible placeholder — reserves the real number's metrics.
                Text("+0.0%")
                    .font(.instrument(.bold, size: 34))
                    .opacity(0)
                // Shimmer block at the reserved size.
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors.surfaceSecondary)
                    .padding(.vertical, 4)
            }
            .shimmer()
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private func heroStat(label: String, value: String, tint: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(colors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "info.circle")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(colors.muted.opacity(0.6))
                if alignment == .leading { Spacer(minLength: 0) }
            }
            Text(value)
                .font(.instrument(.bold, size: 34))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private func frameAlignment(for h: HorizontalAlignment) -> Alignment {
        switch h {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }

    private var heroPicksValue: String  { formatHeroPct(perfVM.result.strategyReturnPct,  suffix: "%") }
    private var heroBenchValue: String  { formatHeroPct(perfVM.result.benchmarkReturnPct, suffix: "%") }
    private var heroAlphaValue: String  { formatHeroPct(perfVM.result.alphaReturnPct,     suffix: "pp") }

    private var heroPicksTint: Color {
        heroTint(value: perfVM.result.strategyReturnPct,
                 vs: perfVM.result.benchmarkReturnPct)
    }
    private var heroBenchTint: Color {
        heroTint(value: perfVM.result.benchmarkReturnPct,
                 vs: perfVM.result.strategyReturnPct)
    }
    private var heroAlphaTint: Color { heroSingleTint(perfVM.result.alphaReturnPct) }

    private func formatHeroPct(_ value: Double, suffix: String) -> String {
        guard perfVM.result.totalDeployed > 0 else { return "—" }
        let x = value * 100
        let sign = x >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(x)))\(suffix)"
    }

    /// Comparison-aware tint: saturated when this value is the more
    /// "extreme in its direction" of the pair — biggest positive or
    /// worst negative. Muted when the other side is more extreme. Mixed
    /// signs always stay saturated because the colour alone separates
    /// them (green vs red).
    private func heroTint(value: Double, vs other: Double) -> Color {
        guard perfVM.result.totalDeployed > 0 else { return colors.foreground }
        let valuePositive = value >= 0
        let otherPositive = other >= 0
        if valuePositive != otherPositive {
            return valuePositive ? .buyGreen : .sellRed
        }
        if valuePositive {
            return value >= other ? .buyGreen : Color.buyGreen.opacity(0.5)
        } else {
            return value <= other ? .sellRed : Color.sellRed.opacity(0.5)
        }
    }

    /// Single-value tint (no comparison) — used by the alpha stat when we
    /// revive it; kept so callers don't break.
    private func heroSingleTint(_ value: Double) -> Color {
        guard perfVM.result.totalDeployed > 0 else { return colors.foreground }
        return value >= 0 ? .buyGreen : .sellRed
    }

    /// Plain-English narration of what the current filter selections mean.
    /// Reads as a single sentence so the user can see the backtest's semantics
    /// without having to infer them from chip labels.
    private var strategySentence: String {
        let amount = perfVM.config.amount.displayName
        let universe = universePhrase(perfVM.config.universe)
        let window = windowPhrase(perfVM.config.timeWindow)
        let exit = exitPhrase(perfVM.config.exitRule)
        let bench = settings.marketBenchmark.displayName
        let count = perfVM.result.dealCount

        guard count > 0 else {
            return "No \(universe) matches \(window). Try widening the window or universe."
        }

        let deployed = formatGbpCompact(perfVM.result.totalDeployed)
        let dealsWord = count == 1 ? "deal" : "deals"
        return "\(amount) into every \(universe) \(window), \(exit) — tracked against \(bench). \(count) \(dealsWord), \(deployed) deployed."
    }

    private func universePhrase(_ u: PerformanceUniverse) -> String {
        switch u {
        case .everyBuy:    return "disclosed buy"
        case .suggested:   return "suggested buy"
        case .significant: return "significant buy"
        case .noteworthy:  return "noteworthy buy"
        }
    }

    private func windowPhrase(_ w: PerformanceTimeWindow) -> String {
        switch w {
        case .days30:  return "from the last 30 days"
        case .days90:  return "from the last 90 days"
        case .days365: return "from the last year"
        case .all:     return "across the full history"
        }
    }

    private func exitPhrase(_ e: PerformanceExitRule) -> String {
        switch e {
        case .horizon30:   return "each held for 30 days"
        case .horizon90:   return "each held for 90 days"
        case .horizon180:  return "each held for 180 days"
        case .horizon365:  return "each held for a year"
        case .holdForever: return "all still held today"
        }
    }

    private func formatGbpCompact(_ value: Double) -> String {
        if value >= 10_000 {
            return "£\(String(format: "%.1f", value / 1_000))k"
        }
        return "£\(String(format: "%.0f", value))"
    }

    // MARK: - Chart section

    @ViewBuilder
    private var chartSection: some View {
        Group {
            if isFirstLoad {
                firstLoadChart
            } else if perfVM.result.strategy.count >= 2 {
                PerformanceChart(
                    strategy: perfVM.result.strategy,
                    benchmark: perfVM.result.benchmark,
                    deployed: perfVM.result.deployed,
                    viewMode: perfVM.config.viewMode
                )
            } else {
                emptyChart
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .opacity(perfVM.isComputing && !isFirstLoad ? 0.45 : 1.0)
        .animation(recomputeAnimation, value: perfVM.isComputing)
    }

    /// Shared easing used across every view that reacts to a recompute,
    /// so the hero, chart, and contributors all breathe in unison.
    private var recomputeAnimation: Animation {
        .easeInOut(duration: 0.22)
    }

    private var firstLoadChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 100, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 100, height: 12)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(colors.surfaceSecondary)
                .frame(height: 200)
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 44, height: 8)
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 44, height: 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
        .shimmer()
    }

    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 22))
                .foregroundStyle(colors.muted.opacity(0.5))
            Text("No qualifying deals in this window")
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Criteria grid (lives INSIDE the hero card)

    private var criteriaGrid: some View {
        VStack(spacing: 6) {
            universeCard
            HStack(spacing: 6) {
                criteriaCard(label: "Window",
                             value: perfVM.config.timeWindow.displayName,
                             action: { activeCriterion = .window })
                criteriaCard(label: "Hold",
                             value: perfVM.config.exitRule.displayName,
                             action: { activeCriterion = .exit })
            }
            HStack(spacing: 6) {
                criteriaCard(label: "Benchmark",
                             value: settings.marketBenchmark.displayName,
                             action: { activeCriterion = .benchmark })
                criteriaCard(label: "Per deal",
                             value: perfVM.config.amount.displayName,
                             action: { activeCriterion = .amount })
            }
        }
    }

    private var universeCard: some View {
        let count = perfVM.result.dealCount
        let countText = count > 0 ? "\(count) deal\(count == 1 ? "" : "s")" : "—"
        return Button {
            activeCriterion = .universe
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("UNIVERSE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(colors.muted)
                HStack(spacing: 8) {
                    Text(perfVM.config.universe.displayName)
                        .font(.instrument(.semiBold, size: 16))
                        .foregroundStyle(colors.foreground)
                    Spacer()
                    Text(countText)
                        .font(.instrument(size: 13))
                        .foregroundStyle(colors.muted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(colors.muted.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func criteriaCard(label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(colors.muted)
                HStack(spacing: 6) {
                    Text(value)
                        .font(.instrument(.semiBold, size: 16))
                        .foregroundStyle(colors.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colors.muted.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - View mode (above the chart — chart-display preference)

    private var viewModeSegmented: some View {
        HStack(spacing: 6) {
            ForEach(PerformanceViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { perfVM.config.viewMode = mode }
                } label: {
                    Text(mode.displayName)
                        .font(.instrument(.medium, size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            perfVM.config.viewMode == mode ? colors.accent.opacity(0.15) : colors.surfaceSecondary,
                            in: Capsule()
                        )
                        .foregroundStyle(perfVM.config.viewMode == mode ? colors.accent : colors.muted)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Criteria sheets

    @ViewBuilder
    private func criteriaSheet(for criterion: ActiveCriterion) -> some View {
        switch criterion {
        case .universe:
            PerformanceCriteriaSheet(
                title: "Universe",
                options: universeOptions,
                selection: $perfVM.config.universe,
                onDismiss: { activeCriterion = nil }
            )
            .ddbxMediumDetent()
        case .window:
            PerformanceCriteriaSheet(
                title: "Window",
                options: windowOptions,
                selection: $perfVM.config.timeWindow,
                onDismiss: { activeCriterion = nil }
            )
            .ddbxMediumDetent()
        case .exit:
            PerformanceCriteriaSheet(
                title: "Hold period",
                options: exitOptions,
                selection: $perfVM.config.exitRule,
                onDismiss: { activeCriterion = nil }
            )
            .ddbxMediumDetent()
        case .benchmark:
            PerformanceCriteriaSheet(
                title: "Benchmark",
                options: benchmarkOptions,
                selection: $settings.marketBenchmark,
                onDismiss: { activeCriterion = nil }
            )
            .ddbxMediumDetent()
        case .amount:
            PerformanceCriteriaSheet(
                title: "Per deal",
                options: amountOptions,
                selection: $perfVM.config.amount,
                onDismiss: { activeCriterion = nil }
            )
            .ddbxMediumDetent()
        }
    }

    private var universeOptions: [PerformanceCriteriaSheet<PerformanceUniverse>.Option] {
        [
            .init(tag: .everyBuy,    label: "Every buy",   description: "Every disclosed director buy."),
            .init(tag: .suggested,   label: "Suggested",   description: "Significant + noteworthy ratings."),
            .init(tag: .significant, label: "Significant", description: "Highest-conviction subset only."),
            .init(tag: .noteworthy,  label: "Noteworthy",  description: "Mid-tier ratings only."),
        ]
    }

    private var windowOptions: [PerformanceCriteriaSheet<PerformanceTimeWindow>.Option] {
        [
            .init(tag: .days30,  label: "Last 30 days", description: "Recent only."),
            .init(tag: .days90,  label: "Last 90 days", description: "Quarter-length view."),
            .init(tag: .days365, label: "Last year",    description: "Full annual cycle."),
            .init(tag: .all,     label: "All",          description: "Everything available (up to 2 years)."),
        ]
    }

    private var exitOptions: [PerformanceCriteriaSheet<PerformanceExitRule>.Option] {
        [
            .init(tag: .horizon30,   label: "30 days",      description: "Close each position 30 days after entry."),
            .init(tag: .horizon90,   label: "90 days",      description: "Close each position 90 days after entry."),
            .init(tag: .horizon180,  label: "180 days",     description: "Close each position 180 days after entry."),
            .init(tag: .horizon365,  label: "1 year",       description: "Close each position 1 year after entry."),
            .init(tag: .holdForever, label: "Hold forever", description: "Never exit — mark-to-market today."),
        ]
    }

    private var benchmarkOptions: [PerformanceCriteriaSheet<MarketBenchmark>.Option] {
        MarketBenchmark.allCases.map {
            .init(tag: $0, label: $0.displayName, description: $0.detail)
        }
    }

    private var amountOptions: [PerformanceCriteriaSheet<PerformanceAmount>.Option] {
        [
            .init(tag: .gbp100,  label: "£100 per deal",   description: "Smallest realistic starting pot."),
            .init(tag: .gbp500,  label: "£500 per deal",   description: nil),
            .init(tag: .gbp1000, label: "£1,000 per deal", description: nil),
        ]
    }

    // MARK: - Contributors

    @ViewBuilder
    private var contributorsSection: some View {
        if !perfVM.result.contributors.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                contributorsHeader
                if !perfVM.config.excludedDealIds.isEmpty {
                    excludedBanner
                }
                VStack(spacing: 0) {
                    ForEach(perfVM.result.contributors) { row in
                        contributorRow(row)
                        if row.id != perfVM.result.contributors.last?.id {
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
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.28),
                           value: perfVM.result.contributors.map(\.id))
            }
            .opacity(perfVM.isComputing ? 0.45 : 1.0)
            .animation(recomputeAnimation, value: perfVM.isComputing)
        }
    }

    private var contributorsHeader: some View {
        HStack {
            Text("Contributors")
                .font(.instrument(.semiBold, size: 16))
                .foregroundStyle(colors.foreground)
            Spacer()
            Text("sorted by impact")
                .font(.instrument(size: 12))
                .foregroundStyle(colors.muted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var excludedBanner: some View {
        let count = perfVM.config.excludedDealIds.count
        return HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 11, weight: .medium))
            Text("\(count) excluded")
                .font(.instrument(.medium, size: 12))
            Spacer()
            Button("Reset") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    perfVM.config.excludedDealIds.removeAll()
                }
            }
            .font(.instrument(.semiBold, size: 12))
            .foregroundStyle(colors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(colors.muted)
        .background(colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func contributorRow(_ row: ContributorRow) -> some View {
        HStack(spacing: 12) {
            Button {
                if let deal = vm.dealings.first(where: { $0.id == row.dealId }) {
                    selectedDeal = deal
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(row.ticker.replacingOccurrences(of: ".L", with: ""))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(colors.foreground)
                                .lineLimit(1)
                            if row.state == .open {
                                Text("OPEN")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(colors.muted)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(colors.surfaceSecondary, in: Capsule())
                                    .fixedSize()
                            }
                            Spacer(minLength: 0)
                        }
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
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = perfVM.config.excludedDealIds.insert(row.dealId)
                }
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(colors.muted.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exclude from backtest")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func formatPct(_ value: Double) -> String {
        let pct = value * 100
        let sign = pct >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(pct)))%"
    }

    private func formatSignedGbp(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        let abs = Swift.abs(value)
        if abs >= 10_000 {
            return "\(sign)£\(String(format: "%.1f", abs / 1_000))k"
        }
        return "\(sign)£\(String(format: "%.0f", abs))"
    }
}
