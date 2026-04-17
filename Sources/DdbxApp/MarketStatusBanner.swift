import SwiftUI

struct MarketStatusBanner: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = LSE.status(at: context.date)
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

    private func copy(for status: MarketStatus) -> String {
        switch status {
        case .preOpen(let opensIn):
            return "Market opens in \(LSE.formatCountdown(opensIn))"
        case .open:
            return "Market is open, scanning for deals"
        case .closed(let reopensTomorrow):
            return reopensTomorrow
                ? "Market is closed, reopens tomorrow"
                : "Market is closed, reopens Monday"
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
