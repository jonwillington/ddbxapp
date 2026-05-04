import SwiftUI

struct DashboardView: View {
    @Environment(\.ddbxColors) private var colors
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pushManager: PushManager
    @EnvironmentObject private var vm: DashboardViewModel
    @ObservedObject private var holidays = BankHolidayProvider.shared
    @State private var selectedDeal: Dealing?
    @State private var filter: DealFilter = .all
    @State private var sortMode: SortMode = .chronological
    @State private var showRowSettings = false
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var showNotifications = false

    enum DealFilter: String, CaseIterable {
        case all = "All"
        case noteworthyPlus = "Standouts"
    }

    enum SortMode {
        case chronological, byLift
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                if vm.isLoading {
                    SkeletonDashboard()
                } else if let failure = vm.failure, vm.dealings.isEmpty {
                    LoadFailureView(failure: failure) {
                        Task { await vm.refresh() }
                    }
                } else {
                    dealingsList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await vm.refresh()
                await vm.fetchLiftPrices(benchmarkTicker: settings.marketBenchmark.ticker)
            }
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
            .sheet(isPresented: $showRowSettings) {
                MetricsSettingsSheet()
                    .environmentObject(settings)
            }
        }
        .task { vm.startPolling() }
        .onChange(of: vm.dealings.isEmpty) { isEmpty in
            // Prices always needed — trend line on every row uses liftPct
            if !isEmpty { Task { await vm.fetchLiftPrices(benchmarkTicker: settings.marketBenchmark.ticker) } }
        }
        .onChange(of: settings.marketBenchmark) { _ in
            Task { await vm.fetchLiftPrices(benchmarkTicker: settings.marketBenchmark.ticker) }
        }
        .onChange(of: pushManager.pendingDealingId) { dealingId in
            guard let dealingId else { return }
            pushManager.pendingDealingId = nil
            if let deal = vm.dealings.first(where: { $0.id == dealingId }) {
                selectedDeal = deal
            } else {
                Task {
                    if let deal = try? await APIClient.shared.dealing(id: dealingId) {
                        selectedDeal = deal
                    }
                }
            }
        }
    }

    // MARK: - Filter

    private func applyFilter(_ deals: [Dealing]) -> [Dealing] {
        guard filter == .noteworthyPlus else { return deals }
        return deals.filter { deal in
            guard let rating = deal.analysis?.rating else { return false }
            return rating == .significant || rating == .noteworthy
        }
    }

    /// Stable partition: `.significant` deals float to the top of a day's list,
    /// everything else keeps its incoming order.
    private func prioritizeSignificant(_ deals: [Dealing]) -> [Dealing] {
        deals.filter { $0.analysis?.rating == .significant }
            + deals.filter { $0.analysis?.rating != .significant }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(DealFilter.allCases, id: \.self) { f in
                Button(f.rawValue) {
                    withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                }
                .font(.instrument(.medium, size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(filter == f ? colors.accent.opacity(0.15) : colors.surfaceSecondary, in: Capsule())
                .foregroundStyle(filter == f ? colors.accent : colors.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var rowSettingsButton: some View {
        Button { showRowSettings = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colors.surfaceSecondary, in: Capsule())
                .foregroundStyle(colors.muted)
        }
    }

    private var liftToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                sortMode = sortMode == .byLift ? .chronological : .byLift
            }
            if sortMode == .byLift {
                Task { await vm.fetchLiftPrices() }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .medium))
                Text("Lift")
                    .font(.instrument(.medium, size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(sortMode == .byLift ? colors.accent.opacity(0.15) : colors.surfaceSecondary, in: Capsule())
            .foregroundStyle(sortMode == .byLift ? colors.accent : colors.muted)
        }
    }

    // MARK: - Dealings list

    private var dealingsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: sortMode == .chronological ? .sectionHeaders : []) {
                // Page title
                HStack {
                    Text("Deals")
                        .font(.instrument(.bold, size: 28))
                        .foregroundStyle(colors.foreground)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                filterBar

                MarketStatusBanner()

                if sortMode == .byLift {
                    liftContent
                } else if filter == .noteworthyPlus {
                    // No Today section — fold everything into the day stream.
                    ForEach(filteredAllDays) { day in
                        dealDaySection(day: day)
                    }
                } else {
                    todaySection

                    // History — flat day sections. Day headers are sticky; when a
                    // day is the first of its month the header carries the month
                    // label above the day label.
                    ForEach(filteredHistoryDays) { day in
                        dealDaySection(day: day)
                    }
                }

                DisclaimerFootnote()
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Lift list

    @ViewBuilder
    private var liftContent: some View {
        if vm.liftLoading {
            ProgressView()
                .padding(40)
                .frame(maxWidth: .infinity)
        } else {
            let sorted = liftSortedDeals
            ForEach(Array(sorted.enumerated()), id: \.element.id) { i, deal in
                DealRow(deal: deal, liftPct: vm.liftPct(for: deal), ftsePct: vm.ftsePct(for: deal), leadingDateLabel: liftDateLabel(deal))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDeal = deal }
                if i < sorted.count - 1 {
                    Divider()
                        .overlay(colors.separator)
                        .padding(.leading, 16)
                }
            }
        }
    }

    private var liftSortedDeals: [Dealing] {
        applyFilter(vm.dealings).sorted { a, b in
            let pa = vm.liftPct(for: a)
            let pb = vm.liftPct(for: b)
            switch (pa, pb) {
            case (let x?, let y?): return x > y
            case (_?, nil): return true
            default: return false
            }
        }
    }

    private func liftDateLabel(_ deal: Dealing) -> String {
        guard let date = Self.liftDateParser.date(from: deal.displayDate) else { return deal.displayDate }
        return Self.liftDateFormatter.string(from: date)
    }

    private static let liftDateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private static let liftDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private var filteredAllDays: [DashboardViewModel.FlatDayGroup] {
        vm.allByDay.compactMap { day in
            let filtered = prioritizeSignificant(applyFilter(day.deals))
            guard !filtered.isEmpty else { return nil }
            return DashboardViewModel.FlatDayGroup(
                key: day.key, dayLabel: day.dayLabel,
                monthKey: day.monthKey, monthLabel: day.monthLabel,
                isFirstOfMonth: day.isFirstOfMonth, deals: filtered
            )
        }
    }

    private var filteredHistoryDays: [DashboardViewModel.FlatDayGroup] {
        vm.historyByDay.compactMap { day in
            let filtered = prioritizeSignificant(applyFilter(day.deals))
            guard !filtered.isEmpty else { return nil }
            return DashboardViewModel.FlatDayGroup(
                key: day.key,
                dayLabel: day.dayLabel,
                monthKey: day.monthKey,
                monthLabel: day.monthLabel,
                isFirstOfMonth: day.isFirstOfMonth,
                deals: filtered
            )
        }
    }

    // MARK: - Today section

    private var todaySection: some View {
        let all = prioritizeSignificant(applyFilter(vm.todayAnalysed + vm.todaySkipped))

        return Section {
            if all.isEmpty {
                noDealsTodayCard
            } else {
                VStack(spacing: 0) {
                    ForEach(all) { deal in
                        DealRow(deal: deal, liftPct: vm.liftPct(for: deal), ftsePct: vm.ftsePct(for: deal))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDeal = deal }
                        if deal.id != all.last?.id {
                            Divider()
                                .overlay(colors.separator)
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(colors.border, lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
            }
        } header: {
            todayHeader
        }
    }

    private var todayHeader: some View {
        HStack {
            Text("Today")
                .font(.instrument(.bold, size: 22))
                .foregroundStyle(colors.foreground)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(colors.background)
    }

    @ViewBuilder
    private var noDealsTodayCard: some View {
        let status = LSE.status(at: Date(), holidays: holidays.englandAndWales)
        if case .closed(let reopens, .holiday(let name)) = status {
            emptyTodayCard(
                icon: "calendar",
                headline: "Closed for \(name)",
                subtitle: "Reopens \(reopensPhrase(reopens))."
            )
        } else {
            emptyTodayCard(
                icon: "clock",
                headline: "No deals have happened yet today",
                subtitle: Self.noDealsSubtitle()
            )
        }
    }

    private func emptyTodayCard(icon: String, headline: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(colors.muted)
            Text(headline)
                .font(.instrument(.semiBold, size: 15))
                .foregroundStyle(colors.foreground)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func reopensPhrase(_ reopens: NextOpen) -> String {
        switch reopens {
        case .tomorrow: return "tomorrow"
        case .named(let day): return "on \(day)"
        }
    }

    /// Contextual subtitle for the empty-today card. Anchored to LSE hours
    /// (08:00–16:30 London). Weekend → relax. Pre-open → coffee. Market open →
    /// waiting on disclosures. After close → day's done.
    static func noDealsSubtitle(now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let weekday = cal.component(.weekday, from: now) // 1=Sun … 7=Sat
        if weekday == 1 || weekday == 7 {
            return "Markets closed for the weekend. Get some sunlight."
        }
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if minutes < 8 * 60 {
            return "Pour your coffee, the market opens soon."
        }
        if minutes < 16 * 60 + 30 {
            return "Market's open. Waiting on the first disclosure."
        }
        return "Check back tomorrow, get some sleep."
    }

    // MARK: - Day section

    private func dealDaySection(day: DashboardViewModel.FlatDayGroup) -> some View {
        Section {
            ForEach(day.deals) { deal in
                DealRow(deal: deal, liftPct: vm.liftPct(for: deal), ftsePct: vm.ftsePct(for: deal))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDeal = deal }

                if deal.id != day.deals.last?.id {
                    Divider()
                        .overlay(colors.separator)
                        .padding(.leading, 16)
                }
            }
        } header: {
            dayHeader(day: day)
        }
    }

    private func dayHeader(day: DashboardViewModel.FlatDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if day.isFirstOfMonth {
                Text(day.monthLabel)
                    .font(.instrument(.bold, size: 15))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
            }
            HStack {
                Text(day.dayLabel)
                    .font(.instrument(.semiBold, size: 14))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(colors.muted)
                Spacer()
                Text("\(day.deals.count) deal\(day.deals.count == 1 ? "" : "s")")
                    .font(.instrument(size: 13))
                    .foregroundStyle(colors.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(colors.background)
    }


}
