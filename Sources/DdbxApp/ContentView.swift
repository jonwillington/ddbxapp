import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = DashboardViewModel()

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("News", systemImage: "newspaper.fill") {
                NewsView()
            }
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
        }
        .tint(.accentBrown)
        .environment(\.ddbxColors, DdbxColors(colorScheme: colorScheme))
        .environment(vm)
    }
}
