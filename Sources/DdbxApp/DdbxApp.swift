import SwiftUI

@main
struct DdbxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var pushManager = PushManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var dashboardVM = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register()
        #if DEBUG
        for family in UIFont.familyNames.sorted() where family.contains("Instrument") {
            print("Font family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
        Self.assertLaunchBackgroundIsTokenised()
        #endif
    }

    #if DEBUG
    /// Guardrail — fails loudly if LaunchBackground.colorset doesn't have a
    /// dark appearance, so a future asset edit can't silently break the
    /// dark-mode splash. Resolves the named colour in both trait collections
    /// and compares; equal ⇒ no dark variant.
    private static func assertLaunchBackgroundIsTokenised() {
        guard let named = UIColor(named: "LaunchBackground") else {
            assertionFailure("LaunchBackground colorset is missing")
            return
        }
        let light = named.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = named.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        assert(light != dark, "LaunchBackground has no dark variant — splash will not honour dark mode")
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(pushManager)
                .environmentObject(subscriptionManager)
                .environmentObject(dashboardVM)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task {
                    appDelegate.pushManager = pushManager
                    await subscriptionManager.load()
                    // Only request notification permission for users who already
                    // have a subscription on launch. New users are asked via
                    // NotificationOnboardingSheet after they start their trial,
                    // so the OS prompt isn't fired before they understand the app.
                    if subscriptionManager.isSubscribed {
                        await pushManager.requestPermission()
                    }
                    // Prefetch deals while paywall is showing. Sync the
                    // benchmark first so the refresh-driven lift-price fetch
                    // hits the right ticker on this very first run.
                    dashboardVM.benchmarkTicker = settings.marketBenchmark.ticker
                    dashboardVM.startPolling()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                BackgroundRefresh.scheduleNext()
            }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var sub: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme

    private var colors: DdbxColors { DdbxColors(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if sub.isLoading {
                ProgressView()
                    .tint(colors.muted)
                    .scaleEffect(1.5)
                    .transition(.opacity)
            } else if sub.isSubscribed {
                ContentView()
                    .transition(.opacity)
            } else {
                PaywallView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sub.isLoading)
        .animation(.easeInOut(duration: 0.2), value: sub.isSubscribed)
    }
}
