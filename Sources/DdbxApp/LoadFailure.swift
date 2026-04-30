import Foundation
import SwiftUI

/// Categorised load failure. We split "offline" out from everything else so
/// the UI can show "No signal" copy when the device genuinely can't reach the
/// network, rather than dumping URLSession's localizedDescription on the user.
enum LoadFailure: Equatable {
    case offline
    case other(String)

    static func from(_ error: Error) -> LoadFailure {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .timedOut,
                 .secureConnectionFailed:
                return .offline
            default:
                return .other(error.localizedDescription)
            }
        }
        return .other(error.localizedDescription)
    }
}

/// Shared empty-state view for load failures. Used by both the Dashboard
/// and News tabs so the offline copy stays consistent.
struct LoadFailureView: View {
    let failure: LoadFailure
    let retry: () -> Void

    @Environment(\.ddbxColors) private var colors

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundStyle(colors.muted)

            Text(title)
                .font(.instrument(.semiBold, size: 17))
                .foregroundStyle(colors.foreground)

            if let detail {
                Text(detail)
                    .font(.instrument(size: 14))
                    .foregroundStyle(colors.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Retry", action: retry)
                .font(.instrument(.semiBold, size: 15))
                .foregroundStyle(colors.accent)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var iconName: String {
        switch failure {
        case .offline: "wifi.slash"
        case .other: "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch failure {
        case .offline: "No signal detected"
        case .other: "Something went wrong"
        }
    }

    private var detail: String? {
        switch failure {
        case .offline:
            return "Check your connection and try again."
        case .other(let message):
            return message.isEmpty ? nil : message
        }
    }
}
