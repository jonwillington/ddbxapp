import SwiftUI

struct MarketStatusBanner: View {
    @Environment(\.ddbxColors) private var colors
    @ObservedObject private var holidays = BankHolidayProvider.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = LSE.status(at: context.date, holidays: holidays.englandAndWales)
            // Bank-holiday closures are surfaced inside the empty-today card
            // instead, so the banner stays out of the way on those days.
            if case .closed(_, .holiday) = status {
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    Circle()
                        .fill(dotColor(for: status))
                        .frame(width: 8, height: 8)

                    Text(copy(for: status))
                        .font(.instrument(.medium, size: 13))
                        .foregroundStyle(colors.foreground)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(colors.separator)
                        .frame(height: 0.5)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .task {
            await holidays.refreshIfStale()
        }
    }

    private func copy(for status: MarketStatus) -> String {
        switch status {
        case .preOpen(let opensIn, let earlyClose):
            let base = "Market opens in \(LSE.formatCountdown(opensIn))"
            if earlyClose != nil {
                return "\(base), early close at \(LSE.formatCloseTime(minuteOfDay: LSE.halfDayCloseMinute))"
            }
            return base
        case .open(let earlyClose):
            if let earlyClose {
                return "Market is open, early close at \(LSE.formatCloseTime(minuteOfDay: LSE.halfDayCloseMinute)) (\(earlyClose))"
            }
            return "Market is open, scanning for deals"
        case .closed(let reopens, let reason):
            return closedCopy(reopens: reopens, reason: reason)
        }
    }

    private func closedCopy(reopens: NextOpen, reason: ClosureReason) -> String {
        let when: String
        switch reopens {
        case .tomorrow: when = "tomorrow"
        case .named(let day): when = day
        }
        switch reason {
        case .holiday(let name):
            return "Closed for \(name), reopens \(when)"
        case .weekend, .afterHours:
            return "Market is closed, reopens \(when)"
        }
    }

    private func dotColor(for status: MarketStatus) -> Color {
        switch status {
        case .open: .buyGreen
        case .preOpen: .orange
        case .closed: colors.muted
        }
    }
}
