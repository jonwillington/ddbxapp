import SwiftUI

struct NotificationsSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pushManager: PushManager

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                if pushManager.notificationHistory.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(pushManager.notificationHistory) { record in
                            notificationRow(record)
                                .listRowBackground(colors.surface)
                                .listRowSeparatorTint(colors.separator)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notifications")
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundStyle(colors.muted)
            Text("No notifications yet")
                .font(.instrument(.semiBold, size: 15))
                .foregroundStyle(colors.foreground)
            Text(DashboardView.noDealsSubtitle())
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func notificationRow(_ record: PushNotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.title)
                    .font(.instrument(.semiBold, size: 14))
                    .foregroundStyle(colors.foreground)
                    .lineLimit(1)
                Spacer()
                Text(timeLabel(record.receivedAt))
                    .font(.instrument(size: 11))
                    .foregroundStyle(colors.muted)
            }
            Text(record.body)
                .font(.instrument(size: 13))
                .foregroundStyle(colors.muted)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.dateFormatter.string(from: date)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()
}
