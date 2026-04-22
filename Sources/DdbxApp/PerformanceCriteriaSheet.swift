import SwiftUI

/// Generic bottom-sheet picker used by the Performance tab's criteria cards.
/// Shows a list of labelled options with optional descriptions and a
/// checkmark against the current selection. Selecting dismisses the sheet.
struct PerformanceCriteriaSheet<T: Hashable>: View {
    struct Option: Identifiable {
        let tag: T
        let label: String
        let description: String?
        var id: Int { tag.hashValue }
    }

    let title: String
    let options: [Option]
    @Binding var selection: T
    var onDismiss: () -> Void

    @Environment(\.ddbxColors) private var colors

    var body: some View {
        NavigationStack {
            List {
                ForEach(options) { option in
                    Button {
                        selection = option.tag
                        onDismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.instrument(.medium, size: 16))
                                    .foregroundStyle(colors.foreground)
                                if let desc = option.description {
                                    Text(desc)
                                        .font(.instrument(size: 13))
                                        .foregroundStyle(colors.muted)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selection == option.tag ? colors.accent : Color.clear)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(colors.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(.instrument(.semiBold, size: 15))
                        .foregroundStyle(colors.accent)
                }
            }
        }
    }
}

extension View {
    /// Applies a medium + large detent on iOS 16.4+. No-op on 16.0–16.3
    /// (sheet will take default full-screen modal size on those versions).
    @ViewBuilder
    func ddbxMediumDetent() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}
