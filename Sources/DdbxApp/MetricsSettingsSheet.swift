import SwiftUI

struct MetricsSettingsSheet: View {
    @Environment(\.ddbxColors) private var colors
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value column")
                            .font(.instrument(.semiBold, size: 12))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(colors.muted)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(ValueColumnMetric.allCases.enumerated()), id: \.element) { i, metric in
                                if i > 0 {
                                    Divider()
                                        .overlay(colors.separator)
                                        .padding(.leading, 16)
                                }
                                Button {
                                    settings.valueColumnMetric = metric
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(metric.displayName)
                                                .font(.instrument(.semiBold, size: 15))
                                                .foregroundStyle(colors.foreground)
                                            Text(metric.detail)
                                                .font(.instrument(size: 13))
                                                .foregroundStyle(colors.muted)
                                        }
                                        Spacer()
                                        if settings.valueColumnMetric == metric {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(colors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .background(colors.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(colors.border, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Customise rows")
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
    }
}
