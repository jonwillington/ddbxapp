import SwiftUI

struct AppSettingsSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pushManager: PushManager

    var body: some View {
        let notifyAllBinding = Binding<Bool>(
            get: { pushManager.notifyLevel == .all },
            set: { pushManager.notifyLevel = $0 ? .all : .noteworthy }
        )
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                List {
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
                    } footer: {
                        Text("Used to compare deal performance against the broader market.")
                            .font(.instrument(size: 12))
                            .foregroundStyle(colors.muted)
                    }

                    // MARK: - Notifications
                    Section {
                        Toggle(isOn: notifyAllBinding) {
                            Text("Notify on every buy")
                                .font(.instrument(size: 15))
                                .foregroundStyle(colors.foreground)
                        }
                        .tint(colors.accent)
                        .listRowBackground(colors.surface)
                    } header: {
                        Text("Notifications")
                            .font(.instrument(.semiBold, size: 12))
                            .foregroundStyle(colors.muted)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    } footer: {
                        Text("Off: only significant & noteworthy trades. On: every analyzed buy.")
                            .font(.instrument(size: 12))
                            .foregroundStyle(colors.muted)
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
    }
}
