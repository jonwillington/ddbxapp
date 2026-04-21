import SwiftUI

// MARK: - Appearance

enum Appearance: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// MARK: - Market benchmark

enum MarketBenchmark: String, CaseIterable, Codable {
    case ftseAllShare
    case ftse100
    case sp500
    case msciWorld

    var displayName: String {
        switch self {
        case .ftseAllShare: "FTSE All-Share"
        case .ftse100:      "FTSE 100"
        case .sp500:        "S&P 500"
        case .msciWorld:    "MSCI World"
        }
    }

    var detail: String {
        switch self {
        case .ftseAllShare: "Broad UK equity market"
        case .ftse100:      "Top 100 UK companies"
        case .sp500:        "500 largest US companies"
        case .msciWorld:    "Global developed markets"
        }
    }

    var ticker: String {
        switch self {
        case .ftseAllShare: "^FTAS"
        case .ftse100:      "^FTSE"
        case .sp500:        "^GSPC"
        case .msciWorld:    "URTH"
        }
    }
}

// MARK: - Row metric enum

enum ValueColumnMetric: String, CaseIterable, Codable {
    case dealSize
    case returnPct
    case currentPrice
    case outperformLabel
    case returnVsFtse

    var displayName: String {
        switch self {
        case .dealSize:        "Deal size (£)"
        case .returnPct:       "Return (%)"
        case .currentPrice:    "Current price"
        case .outperformLabel: "Outperform / Underperform"
        case .returnVsFtse:    "Return vs FTSE"
        }
    }

    var detail: String {
        switch self {
        case .dealSize:        "Show deal value in £K / £M"
        case .returnPct:       "Show % return since purchase"
        case .currentPrice:    "Show current share price"
        case .outperformLabel: "Beat or trailed the FTSE All-Share"
        case .returnVsFtse:    "% return relative to FTSE All-Share"
        }
    }

    var requiresPriceData: Bool { self != .dealSize }
}

// MARK: - App settings

final class AppSettings: ObservableObject {
    @Published var appearance: Appearance = .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "ddbx.appearance") }
    }

    @Published var valueColumnMetric: ValueColumnMetric = .dealSize {
        didSet { UserDefaults.standard.set(valueColumnMetric.rawValue, forKey: "ddbx.valueColumnMetric") }
    }

    @Published var marketBenchmark: MarketBenchmark = .ftseAllShare {
        didSet { UserDefaults.standard.set(marketBenchmark.rawValue, forKey: "ddbx.marketBenchmark") }
    }

    var needsPriceData: Bool { valueColumnMetric.requiresPriceData }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "ddbx.appearance"),
           let a = Appearance(rawValue: raw) { appearance = a }
        if let raw = UserDefaults.standard.string(forKey: "ddbx.valueColumnMetric"),
           let v = ValueColumnMetric(rawValue: raw) { valueColumnMetric = v }
        if let raw = UserDefaults.standard.string(forKey: "ddbx.marketBenchmark"),
           let b = MarketBenchmark(rawValue: raw) { marketBenchmark = b }
        // legacy "ddbx.rowDetailMetrics" key no longer used
    }
}

// MARK: - Color tokens

extension Color {

    // MARK: Light palette (warm paper)

    static let lightBackground      = Color(hex: 0xF5F0E8)
    static let lightSurface         = Color(hex: 0xFAF7F2)
    static let lightSurfaceSecondary = Color(hex: 0xF0EBE2)
    static let lightForeground      = Color(hex: 0x1A1612)
    static let lightMuted           = Color(hex: 0x8C8278)
    static let lightBorder          = Color(hex: 0xE8E0D5)
    static let lightSeparator       = Color(hex: 0xDDD4C7)

    // MARK: Dark palette (warm browns, from dd-site oklch tokens)

    static let darkBackground       = Color(hex: 0x0F0602)
    static let darkSurface          = Color(hex: 0x190E06)
    static let darkSurfaceSecondary = Color(hex: 0x20160F)
    static let darkForeground       = Color(hex: 0xE9E4DC)
    static let darkMuted            = Color(hex: 0x897E74)
    static let darkBorder           = Color(hex: 0x2F241C)
    static let darkSeparator        = Color(hex: 0x281D15)

    // MARK: Semantic (adapt to color scheme)

    static let accentBrown          = Color(hex: 0x6B5038)

    // MARK: Rating colors (warm browns matching dd-site)

    static let ratingSignificant      = Color(hex: 0x6B2F0A) // dark brown
    static let ratingSignificantBg    = Color(hex: 0x8B4513) // saddle brown
    static let ratingNoteworthy       = Color(hex: 0x4A3520) // tan brown
    static let ratingNoteworthyBg     = Color(hex: 0x6B5038) // medium brown
    static let ratingMinor            = Color(hex: 0x7E766C) // warm grey
    static let ratingMinorBg          = Color(hex: 0xC0B4A6) // light warm grey
    static let ratingRoutine          = Color(hex: 0xB0A898) // dim warm grey
    static let ratingRoutineBg        = Color(hex: 0xD8D0C6) // pale warm grey

    // Dark mode rating colors
    static let ratingSignificantDark  = Color(hex: 0xE8A878)
    static let ratingNoteworthyDark   = Color(hex: 0xC4A882)
    static let ratingMinorDark        = Color(hex: 0x7E766C)
    static let ratingRoutineDark      = Color(hex: 0xB0A898)

    // MARK: Transaction type

    static let buyGreen             = Color(hex: 0x2E7D32)
    static let sellRed              = Color(hex: 0xC62828)
}

// MARK: - Adaptive tokens (resolve per color scheme)

struct DdbxColors {
    let colorScheme: ColorScheme

    var background: Color       { colorScheme == .dark ? .darkBackground : .lightBackground }
    var surface: Color          { colorScheme == .dark ? .darkSurface : .lightSurface }
    var surfaceSecondary: Color { colorScheme == .dark ? .darkSurfaceSecondary : .lightSurfaceSecondary }
    var foreground: Color       { colorScheme == .dark ? .darkForeground : .lightForeground }
    var muted: Color            { colorScheme == .dark ? .darkMuted : .lightMuted }
    var border: Color           { colorScheme == .dark ? .darkBorder : .lightBorder }
    var separator: Color        { colorScheme == .dark ? .darkSeparator : .lightSeparator }
    var accent: Color           { .accentBrown }

    func ratingColor(_ rating: Rating) -> Color {
        switch rating {
        case .significant: colorScheme == .dark ? .ratingSignificantDark : .ratingSignificant
        case .noteworthy:  colorScheme == .dark ? .ratingNoteworthyDark : .ratingNoteworthy
        case .minor:       colorScheme == .dark ? .ratingMinorDark : .ratingMinor
        case .routine:     colorScheme == .dark ? .ratingRoutineDark : .ratingRoutine
        }
    }
}

// MARK: - Environment key

private struct DdbxColorsKey: EnvironmentKey {
    static let defaultValue = DdbxColors(colorScheme: .light)
}

extension EnvironmentValues {
    var ddbxColors: DdbxColors {
        get { self[DdbxColorsKey.self] }
        set { self[DdbxColorsKey.self] = newValue }
    }
}

// MARK: - Availability helpers

extension View {
    /// Applies `.presentationBackground(_:)` on iOS 16.4+; no-op on iOS 16.0–16.3.
    @ViewBuilder
    func ddbxPresentationBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(style)
        } else {
            self
        }
    }
}

// MARK: - Hex initializer

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
