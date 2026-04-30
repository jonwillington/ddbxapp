import SwiftUI

struct ContentView: View {
    enum TabSelection: Hashable { case dashboard, performance, news, search }

    private static let notifOnboardingShownKey = "ddbx.notifOnboardingShown"

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: DashboardViewModel
    @EnvironmentObject private var sub: SubscriptionManager
    @EnvironmentObject private var pushManager: PushManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: TabSelection = .dashboard
    @State private var showNotificationOnboarding = false

    var body: some View {
        tabs
            .tint(.accentBrown)
            .environment(\.ddbxColors, DdbxColors(colorScheme: colorScheme))
            .environmentObject(vm)
            .task {
                await maybeShowNotificationOnboarding()
            }
            .sheet(isPresented: $showNotificationOnboarding) {
                NotificationOnboardingSheet()
                    .environmentObject(pushManager)
            }
    }

    /// Fires once per fresh subscription: if the user just purchased and the
    /// OS hasn't recorded a notification decision yet, show the onboarding
    /// sheet. The UserDefaults flag guards against re-showing on relaunch
    /// even if the user dismisses with X.
    private func maybeShowNotificationOnboarding() async {
        guard sub.justPurchased else { return }
        sub.justPurchased = false

        let alreadyShown = UserDefaults.standard.bool(forKey: Self.notifOnboardingShownKey)
        guard !alreadyShown else { return }

        let status = await pushManager.currentAuthorizationStatus()
        guard status == .notDetermined else { return }

        UserDefaults.standard.set(true, forKey: Self.notifOnboardingShownKey)
        showNotificationOnboarding = true
    }

    @ViewBuilder
    private var tabs: some View {
        let dismissSearch: () -> Void = { selection = .dashboard }
        if #available(iOS 18.0, *) {
            // iOS 18+: the search role pins Search to the far right; on iOS 26
            // it also renders the floating search pill with a minimized tab bar.
            TabView(selection: $selection) {
                Tab("Dashboard", systemImage: "chart.bar.fill", value: .dashboard) {
                    DashboardView()
                }
                Tab("Performance", systemImage: "chart.xyaxis.line", value: .performance) {
                    PerformanceView()
                }
                Tab("News", systemImage: "newspaper.fill", value: .news) {
                    NewsView()
                }
                Tab(value: .search, role: .search) {
                    SearchView(onDismiss: dismissSearch)
                }
            }
        } else {
            TabView(selection: $selection) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                    .tag(TabSelection.dashboard)
                PerformanceView()
                    .tabItem { Label("Performance", systemImage: "chart.xyaxis.line") }
                    .tag(TabSelection.performance)
                NewsView()
                    .tabItem { Label("News", systemImage: "newspaper.fill") }
                    .tag(TabSelection.news)
                SearchView(onDismiss: dismissSearch)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(TabSelection.search)
            }
        }
    }
}
