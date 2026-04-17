import SwiftUI

extension Font {
    /// Instrument Sans that scales with Dynamic Type.
    /// The `size` is the base size at the default content size category;
    /// it scales up/down with the user's accessibility settings.
    static func instrument(_ weight: InstrumentWeight = .regular, size: CGFloat) -> Font {
        .custom(weight.fontName, size: size, relativeTo: closestStyle(for: size))
    }

    /// Instrument Sans pinned to a specific text style for Dynamic Type scaling.
    static func instrumentRelative(_ weight: InstrumentWeight = .regular, style: TextStyle) -> Font {
        .custom(weight.fontName, size: style.defaultSize, relativeTo: style)
    }

    enum InstrumentWeight: CaseIterable {
        case regular, medium, semiBold, bold

        var fontName: String {
            switch self {
            case .regular:  "InstrumentSans-Regular"
            case .medium:   "InstrumentSans-Medium"
            case .semiBold: "InstrumentSans-SemiBold"
            case .bold:     "InstrumentSans-Bold"
            }
        }
    }

    /// Map a point size to the nearest text style for Dynamic Type scaling.
    private static func closestStyle(for size: CGFloat) -> TextStyle {
        switch size {
        case ...11:     .caption2
        case 12:        .caption
        case 13:        .footnote
        case 14...15:   .subheadline
        case 16:        .callout
        case 17:        .body
        case 18...21:   .title3
        case 22...27:   .title2
        case 28...33:   .title
        default:        .largeTitle
        }
    }
}

// MARK: - Default sizes for Dynamic Type base sizes

extension Font.TextStyle {
    var defaultSize: CGFloat {
        switch self {
        case .largeTitle:   34
        case .title:        28
        case .title2:       22
        case .title3:       20
        case .headline:     17
        case .body:         17
        case .callout:      16
        case .subheadline:  15
        case .footnote:     13
        case .caption:      12
        case .caption2:     11
        @unknown default:   17
        }
    }
}
