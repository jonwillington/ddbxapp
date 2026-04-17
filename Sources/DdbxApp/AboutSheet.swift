import SwiftUI

// MARK: - Disclaimer footnote

struct DisclaimerFootnote: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        Text("This app does not constitute financial advice. Past performance is not a reliable indicator of future results. Director dealings data is sourced from regulatory filings and may contain errors or omissions. AI-generated analysis is provided for informational purposes only and should not be relied upon for investment decisions. You should conduct your own research and consult a qualified financial adviser before making any investment. ddbx accepts no liability for losses arising from the use of this information.")
            .font(.instrument(size: 11))
            .foregroundStyle(colors.muted)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Logo button for toolbar

struct LogoButton: View {
    @Environment(\.ddbxColors) private var colors
    @Binding var showAbout: Bool

    var body: some View {
        Button { showAbout = true } label: {
            Image("Logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundStyle(colors.foreground)
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 0))
        .tint(.clear)
    }
}

// MARK: - About sheet

struct AboutSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?

    private let bullets = [
        "Real-time UK director dealing alerts",
        "AI-rated with conviction scoring",
        "6-point checklist on every trade",
        "Track performance vs the market",
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .foregroundStyle(colors.foreground)
                .padding(.top, 8)

            Text("Director Dealings, Decoded")
                .font(.instrument(.semiBold, size: 18))
                .foregroundStyle(colors.foreground)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(colors.accent)
                            .padding(.top, 2)
                        Text(bullet)
                            .font(.instrument(size: 15))
                            .foregroundStyle(colors.foreground.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                selectedURL = URL(string: "https://ddbx.uk")
            } label: {
                HStack(spacing: 6) {
                    Text("Visit ddbx.uk")
                        .font(.instrument(.semiBold, size: 16))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(colors.accent, in: RoundedRectangle(cornerRadius: 12))
            }

            DisclaimerFootnote()
        }
        .padding(24)
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
