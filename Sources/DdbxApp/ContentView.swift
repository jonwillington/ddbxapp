import SwiftUI

struct ContentView: View {
    enum TabSelection: Hashable { case dashboard, performance, news, search }

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = DashboardViewModel()
    @State private var selection: TabSelection = .dashboard

    var body: some View {
        tabs
            .tint(.accentBrown)
            .environment(\.ddbxColors, DdbxColors(colorScheme: colorScheme))
            .environmentObject(vm)
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
