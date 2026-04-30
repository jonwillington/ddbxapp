import StoreKit
import SwiftUI

struct PaywallView: View {
    /// When true, renders an X close button in the top-right. Used when the
    /// view is presented from inside the app (logo tap, settings upgrade)
    /// rather than as the root sign-in surface.
    var showsClose: Bool = false

    @EnvironmentObject private var sub: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = "01"
    @State private var browserURL: URL?

    private var colors: DdbxColors { DdbxColors(colorScheme: colorScheme) }
    private var selectedProduct: Product? { sub.products.first { $0.id == selectedID } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            paywallBody

            if showsClose {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .padding(.top, 28)
                .padding(.trailing, 16)
            }
        }
    }

    private var paywallBody: some View {
        ZStack(alignment: .bottom) {
            // Dark brown header backdrop — light sheet sits on top
            Color(hex: 0x1F1208).ignoresSafeArea()
            circleZone
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            // Off-white rounded sheet — sized to content, floats ~180pt from top
            VStack(spacing: 0) {
                logoTagline
                featuresSection.padding(.top, 20)
                if sub.isSubscribed {
                    subscribedSection.padding(.top, 20)
                } else if sub.isLoading {
                    ProgressView().tint(colors.muted).padding(.vertical, 20)
                } else if sub.products.isEmpty {
                    VStack(spacing: 12) {
                        Text(sub.loadError ?? "Subscriptions unavailable. Please try again later.")
                            .font(.instrument(size: 14))
                            .foregroundStyle(colors.muted)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await sub.reload() }
                        } label: {
                            Text("Try Again")
                                .font(.instrument(.semiBold, size: 15))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.vertical, 20)
                } else {
                    productsSection.padding(.top, 20)
                    ctaSection.padding(.top, 16)
                }
                footerSection.padding(.top, 20)
                #if DEBUG
                Button("Skip (Debug)") { sub.debugUnlock() }
                    .font(.instrument(size: 11))
                    .foregroundStyle(colors.muted)
                    .padding(.top, 6)
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
            .background(
                Color(hex: 0xFAF7F2)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: -4)
            )
            .padding(.top, 200)
        }
        .onChange(of: sub.isSubscribed) { subscribed in
            // Auto-dismiss only on a fresh purchase, i.e. when the view was
            // shown to a non-subscriber. Subscribers seeing the splash via
            // logo tap shouldn't be force-dismissed.
            if subscribed && !showsClose { dismiss() }
        }
        .sheet(item: $browserURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Subscribed state

    private var subscribedSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.black)
                Text("You're subscribed")
                    .font(.instrument(.semiBold, size: 16))
                    .foregroundStyle(.black)
            }
            Button {
                browserURL = URL(string: "https://apps.apple.com/account/subscriptions")
            } label: {
                Text("Manage subscription")
                    .font(.instrument(.semiBold, size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Circle zone

    private var circleZone: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let zoneH: CGFloat = 200

                // Slow-drifting warm radial glow — anchors the dark backdrop
                TimelineView(.animation(minimumInterval: 0.016, paused: false)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let cx = 0.45 + 0.18 * sin(t * 0.18)
                    let cy = 0.30 + 0.18 * cos(t * 0.13)
                    RadialGradient(
                        colors: [Color(hex: 0x6B4520).opacity(0.55), Color.clear],
                        center: UnitPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: 220
                    )
                    .ignoresSafeArea()
                }

                // Large filled ambient orbs — pulsing opacity + scale, dd-site style
                AmbientOrb(size: 220, color: Color(hex: 0x8B5E2E), duration: 3.5, peakOpacity: 0.55)
                    .position(x: w * 0.18, y: zoneH * 0.20)
                AmbientOrb(size: 190, color: Color(hex: 0x6B4520), duration: 4.2, peakOpacity: 0.50)
                    .position(x: w * 0.78, y: zoneH * 0.30)
                AmbientOrb(size: 170, color: Color(hex: 0xA67038), duration: 3.8, peakOpacity: 0.42)
                    .position(x: w * 0.55, y: zoneH * 0.95)
                AmbientOrb(size: 150, color: Color(hex: 0x4A2F18), duration: 5.0, peakOpacity: 0.65)
                    .position(x: w * 0.08, y: zoneH * 0.90)
                AmbientOrb(size: 130, color: Color(hex: 0xC8843E), duration: 4.6, peakOpacity: 0.38)
                    .position(x: w * 0.40, y: zoneH * 0.10)
                AmbientOrb(size: 160, color: Color(hex: 0x5C3818), duration: 3.2, peakOpacity: 0.55)
                    .position(x: w * 0.92, y: zoneH * 0.85)
                AmbientOrb(size: 110, color: Color(hex: 0x9A6028), duration: 5.4, peakOpacity: 0.48)
                    .position(x: w * 0.30, y: zoneH * 0.60)

                // Ring orb — rare, single outline for accent
                RingOrb(size: 220, color: Color(hex: 0xB07840), duration: 4.5, peakOpacity: 0.32)
                    .position(x: w * 0.88, y: zoneH * 0.55)

                // Noteworthy deal — single, occasional, varied fade speed
                let dotZone = CGSize(width: geo.size.width, height: zoneH)
                NoteworthyDot(containerSize: dotZone, color: Color(hex: 0xE8B878), initialDelay: 1.2)

                // Film grain — adds tactility to the dark backdrop
                GrainOverlay()
            }
        }
    }

    // MARK: - Logo + tagline

    private var logoTagline: some View {
        Image("Logo")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(height: 34)
            .foregroundStyle(Color(hex: 0x1E1506))
            .padding(.top, 28)
            .padding(.bottom, 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            FeatureRow(text: "Every closed director deal on the LSE", colors: colors)
            FeatureRow(text: "Deal ratings: Significant, Noteworthy & more", colors: colors)
            FeatureRow(text: "Performance vs FTSE, S&P 500 & more", colors: colors)
            FeatureRow(text: "Push alerts for standout deals", colors: colors)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: 8) {
            ForEach(sub.products, id: \.id) { product in
                ProductCard(product: product, isSelected: product.id == selectedID) {
                    selectedID = product.id
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await sub.purchase(product) }
            } label: {
                ZStack {
                    if sub.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start 7-Day Free Trial")
                            .font(.instrument(.semiBold, size: 17))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(sub.isPurchasing || selectedProduct == nil)

            if let note = trialNote {
                Text(note)
                    .font(.instrument(size: 12))
                    .foregroundStyle(colors.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var trialNote: String? {
        guard let product = selectedProduct else { return nil }
        let period: String
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:  period = "year"
        case .month: period = "month"
        default:     period = "period"
        }
        return "7 days free, then \(product.displayPrice)/\(period) · Cancel anytime"
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 14) {
            Button("Restore Purchases") { Task { await sub.restore() } }
            dot
            Button("Privacy") { browserURL = URL(string: "https://ddbx.uk/privacy") }
            dot
            Button("Terms") { browserURL = URL(string: "https://ddbx.uk/terms") }
        }
        .font(.instrument(size: 13))
        .foregroundStyle(colors.muted)
    }

    private var dot: some View {
        Text("·").foregroundStyle(colors.muted).font(.instrument(size: 13))
    }
}

// MARK: - Ambient orb (large filled, soft pulse)

private struct AmbientOrb: View {
    let size: CGFloat
    let color: Color
    let duration: Double
    let peakOpacity: Double
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 12)
            .opacity(pulse ? peakOpacity : peakOpacity * 0.05)
            .scaleEffect(pulse ? 1.18 : 0.82)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Ring orb (outline, sharper contrast)

private struct RingOrb: View {
    let size: CGFloat
    let color: Color
    let duration: Double
    let peakOpacity: Double
    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.25)
            .frame(width: size, height: size)
            .opacity(pulse ? peakOpacity : peakOpacity * 0.35)
            .scaleEffect(pulse ? 1.08 : 0.94)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Grain overlay (seeded noise, stable across redraws)

private struct GrainOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0xC0FFEE)
            let count = Int((size.width * size.height) / 14)
            for _ in 0..<count {
                let x = CGFloat(rng.unitFloat()) * size.width
                let y = CGFloat(rng.unitFloat()) * size.height
                let isLight = rng.unitFloat() > 0.5
                let alpha = 0.04 + rng.unitFloat() * 0.18
                ctx.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(isLight ? .white.opacity(alpha) : .black.opacity(alpha))
                )
            }
        }
        .blendMode(.overlay)
        .opacity(0.22)
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func unitFloat() -> Double {
        Double(next() & 0xFFFFFF) / Double(0x1000000)
    }
}

// MARK: - Noteworthy dot (random position each cycle)

private struct NoteworthyDot: View {
    let containerSize: CGSize
    let color: Color
    let initialDelay: Double

    @State private var expanding = true
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 0.5)
                .frame(width: 16, height: 16)
                .scaleEffect(expanding ? 6.0 : 1.0)
                .opacity(expanding ? 0 : 0.50)
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(expanding ? 0 : 0.6), radius: 5)
                .opacity(expanding ? 0 : 0.92)
        }
        .position(x: x, y: y)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            while !Task.isCancelled {
                let newX = CGFloat.random(in: containerSize.width * 0.18 ... containerSize.width * 0.82)
                let newY = CGFloat.random(in: containerSize.height * 0.18 ... containerSize.height * 0.82)

                // Kill any in-flight animation before snapping to new position
                withAnimation(nil) {
                    x = newX
                    y = newY
                    expanding = false
                }
                try? await Task.sleep(nanoseconds: 32_000_000)  // two frames

                // Wide variance so some flare out fast, others linger
                let outDuration = Double.random(in: 1.4 ... 5.5)
                withAnimation(.easeOut(duration: outDuration)) {
                    expanding = true
                }

                // Long irregular gap — keeps the expanding ring rare
                let pause = outDuration + 0.4 + Double.random(in: 3.5 ... 8.0)
                try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            }
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let text: String
    let colors: DdbxColors

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.accent)
                .frame(width: 16)
            Text(text)
                .font(.instrument(size: 15))
                .foregroundStyle(colors.foreground)
        }
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    private var isAnnual: Bool { product.id == "01" }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(isAnnual ? "Annual" : "Monthly")
                        .font(.instrument(.semiBold, size: 15))
                        .foregroundStyle(.primary)
                    if isAnnual {
                        Text("Best Value")
                            .font(.instrument(.semiBold, size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                }
                Text(isAnnual ? "\(product.displayPrice)/year" : "\(product.displayPrice)/month")
                    .font(.instrument(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(.black, lineWidth: isSelected ? 1.5 : 0.75)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(.black)
                    .frame(width: 11, height: 11)
                    .scaleEffect(isSelected ? 1.03 : 0.2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.black, lineWidth: isSelected ? 1 : 0.5)
                .opacity(isSelected ? 0.7 : 0.18)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.68), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
