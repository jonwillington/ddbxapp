import SwiftUI

@main
struct DdbxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var pushManager = PushManager()
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
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(pushManager)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task {
                    appDelegate.pushManager = pushManager
                    await pushManager.requestPermission()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                BackgroundRefresh.scheduleNext()
            }
        }
    }
}
