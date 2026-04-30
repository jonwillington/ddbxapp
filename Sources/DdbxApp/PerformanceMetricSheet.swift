import SwiftUI

enum PerformanceMetricKind: Identifiable {
    case picks
    case benchmark(name: String)
    var id: String {
        switch self {
        case .picks:             return "picks"
        case .benchmark(let n): return "benchmark-\(n)"
        }
    }
}

struct PerformanceMetricSheet: View {
    let kind: PerformanceMetricKind
    let config: StrategyConfig

    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabHandle
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    explanation
                    exampleBox
                    howItWorksSection
                }
                .padding(24)
                .padding(.bottom, 8)
            }
        }
        .background(colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Sections

    private var grabHandle: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(colors.border)
                .frame(width: 36, height: 4)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.instrument(.bold, size: 22))
                .foregroundStyle(colors.foreground)
            Text(subtitle)
                .font(.instrument(size: 14))
                .foregroundStyle(colors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: some View {
        Text(bodyText)
            .font(.instrument(size: 15))
            .foregroundStyle(colors.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    private var exampleBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(colors.muted)
            Text(exampleText)
                .font(.instrument(size: 14))
                .foregroundStyle(colors.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(colors.muted)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(colors.background)
                            .frame(width: 20, height: 20)
                            .background(colors.muted.opacity(0.5), in: Circle())
                        Text(step)
                            .font(.instrument(size: 14))
                            .foregroundStyle(colors.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Copy

    private var title: String {
        switch kind {
        case .picks:             return "What is Picks %?"
        case .benchmark(let n): return "What is \(n) %?"
        }
    }

    private var subtitle: String {
        switch kind {
        case .picks:
            return "The return from following director buying signals"
        case .benchmark:
            return "The return from passive index investing over the same period"
        }
    }

    private var bodyText: String {
        switch kind {
        case .picks:
            let amount = config.amount.displayName
            let universe = universeLabel(config.universe)
            let exit = exitLabel(config.exitRule)
            return "Every time a UK director makes \(universe), this backtest invests \(amount) in that company's shares. Picks % is the combined return across all those positions — from each purchase date \(exit)."
        case .benchmark(let name):
            let amount = config.amount.displayName
            let exit = exitLabel(config.exitRule)
            return "At the same moment as each director buy signal, this backtest invests \(amount) into \(name) instead. Benchmark % shows what a passive index investor would have earned — using the identical schedule, held \(exit)."
        }
    }

    private var exampleText: String {
        let amount = config.amount.displayName
        switch kind {
        case .picks:
            return "If 10 director buys each triggered a \(amount) investment and Picks % is +8.4%, your combined portfolio gained +8.4% on the capital you deployed."
        case .benchmark(let name):
            return "If Picks % is +12% and \(name) % is +6%, director picks outperformed the index by 6 percentage points over that window — they earned twice the market return."
        }
    }

    private var steps: [String] {
        let amount = config.amount.displayName
        switch kind {
        case .picks:
            return [
                "Each qualifying director buy triggers a \(amount) simulated purchase of that company's stock.",
                "The position is held according to your exit rule, then closed at the market price on that date.",
                "Returns from every position are averaged to produce Picks %.",
            ]
        case .benchmark(let name):
            return [
                "At the same timestamp as each director buy, \(amount) is notionally invested into \(name).",
                "Each notional \(name) investment is held for the same duration as the corresponding director pick.",
                "Returns from all those \(name) investments are averaged to produce Benchmark %.",
            ]
        }
    }

    // MARK: - Helpers

    private func universeLabel(_ u: PerformanceUniverse) -> String {
        switch u {
        case .everyBuy:    return "any disclosed buy"
        case .suggested:   return "a suggested buy"
        case .significant: return "a significant buy"
        case .noteworthy:  return "a noteworthy buy"
        }
    }

    private func exitLabel(_ e: PerformanceExitRule) -> String {
        switch e {
        case .horizon30:   return "and held for 30 days"
        case .horizon90:   return "and held for 90 days"
        case .horizon180:  return "and held for 180 days"
        case .horizon365:  return "and held for a year"
        case .holdForever: return "and held to today"
        }
    }
}
