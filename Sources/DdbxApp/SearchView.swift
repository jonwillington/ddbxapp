import SwiftUI

struct SearchView: View {
    let onDismiss: () -> Void

    @Environment(\.ddbxColors) private var colors
    @EnvironmentObject private var vm: DashboardViewModel
    @State private var searchText = ""
    @State private var selectedDeal: Dealing?

    private var filteredDealings: [Dealing] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return vm.dealings.filter {
            $0.ticker.lowercased().contains(q) ||
            $0.company.lowercased().contains(q) ||
            $0.director.name.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                if searchText.isEmpty {
                    emptyPrompt
                } else if filteredDealings.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Ticker, company, or director")
            .sheet(item: $selectedDeal) { deal in
                DealDetailView(deal: deal)
            }
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredDealings) { deal in
                    DealRow(deal: deal)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedDeal = deal }

                    if deal.id != filteredDealings.last?.id {
                        Divider()
                            .overlay(colors.separator)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(colors.muted)
            Text("Search deals by ticker, company, or director")
                .font(.instrument(size: 15))
                .foregroundStyle(colors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Text("No results")
                .font(.instrument(.medium, size: 17))
                .foregroundStyle(colors.foreground)
            Text("Try a different search term")
                .font(.instrument(size: 14))
                .foregroundStyle(colors.muted)
        }
        .padding()
    }
}
