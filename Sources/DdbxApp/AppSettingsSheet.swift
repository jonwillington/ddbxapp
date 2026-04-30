import SwiftUI

struct AppSettingsSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pushManager: PushManager
    @EnvironmentObject private var sub: SubscriptionManager
    @State private var showPaywall = false

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                List {
                    // MARK: - Subscription
                    Section {
                        if sub.isSubscribed {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DDBX Premium")
                                        .font(.instrument(.semiBold, size: 15))
                                        .foregroundStyle(colors.foreground)
                                    Text("Active")
                                        .font(.instrument(size: 12))
                                        .foregroundStyle(Color.buyGreen)
                                }
                                Spacer()
                                Button("Manage") {
                                    openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                                }
                                .font(.instrument(size: 14))
                                .foregroundStyle(colors.accent)
                            }
                            .listRowBackground(colors.surface)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Text("Subscribe to DDBX")
                                        .font(.instrument(size: 15))
                                        .foregroundStyle(colors.foreground)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(colors.muted)
                                }
                            }
                            .listRowBackground(colors.surface)
                        }
                    } header: {
                        Text("Subscription")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    // MARK: - Appearance
                    Section {
                        ForEach(Appearance.allCases, id: \.self) { option in
                            Button {
                                settings.appearance = option
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .font(.instrument(size: 15))
                                        .foregroundStyle(colors.foreground)
                                    Spacer()
                                    if settings.appearance == option {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(colors.accent)
                                    }
                                }
                            }
                            .listRowBackground(colors.surface)
                        }
                    } header: {
                        Text("Appearance")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    // MARK: - Market benchmark
                    Section {
                        ForEach(MarketBenchmark.allCases, id: \.self) { benchmark in
                            Button {
                                settings.marketBenchmark = benchmark
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(benchmark.displayName)
                                            .font(.instrument(size: 15))
                                            .foregroundStyle(colors.foreground)
                                        Text(benchmark.detail)
                                            .font(.instrument(size: 12))
                                            .foregroundStyle(colors.muted)
                                    }
                                    Spacer()
                                    if settings.marketBenchmark == benchmark {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(colors.accent)
                                    }
                                }
                            }
                            .listRowBackground(colors.surface)
                        }
                    } header: {
                        Text("Market Benchmark")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.top, 12)
                    } footer: {
                        Text("Used to compare deal performance against the broader market.")
                            .font(.instrument(size: 12))
                            .foregroundStyle(colors.muted)
                    }

                    // MARK: - Deal notifications
                    Section {
                        ForEach(NotifyLevel.allCases, id: \.self) { level in
                            Button {
                                pushManager.notifyLevel = level
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(level.title)
                                            .font(.instrument(size: 15))
                                            .foregroundStyle(colors.foreground)
                                        Text(level.subtitle)
                                            .font(.instrument(size: 12))
                                            .foregroundStyle(colors.muted)
                                    }
                                    Spacer()
                                    if pushManager.notifyLevel == level {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(colors.accent)
                                    }
                                }
                            }
                            .listRowBackground(colors.surface)
                        }
                    } header: {
                        Text("Deal Notifications")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.top, 12)
                    } footer: {
                        Text("Default: standouts only.")
                            .font(.instrument(size: 12))
                            .foregroundStyle(colors.muted)
                    }

                    // MARK: - Daily summary
                    Section {
                        Toggle(isOn: Binding(
                            get: { pushManager.digestEnabled },
                            set: { pushManager.digestEnabled = $0 }
                        )) {
                            Text("Morning & close")
                                .font(.instrument(size: 15))
                                .foregroundStyle(colors.foreground)
                        }
                        .tint(colors.accent)
                        .listRowBackground(colors.surface)
                    } header: {
                        Text("Daily Summary")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.top, 12)
                    } footer: {
                        Text("A recap at market open and after close.")
                            .font(.instrument(size: 12))
                            .foregroundStyle(colors.muted)
                    }

                    // MARK: - Version
                    Section {
                        HStack {
                            Spacer()
                            Text(Self.versionString)
                                .font(.instrument(size: 12))
                                .foregroundStyle(colors.muted)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.instrument(.semiBold, size: 15))
                        .foregroundStyle(colors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .ddbxPresentationBackground(colors.background)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(showsClose: true)
                .environmentObject(sub)
        }
    }
}
