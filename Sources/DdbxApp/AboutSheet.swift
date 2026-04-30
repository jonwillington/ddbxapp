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

