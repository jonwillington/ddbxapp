import StoreKit
import os.log

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var isSubscribed = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isPurchasing = false
    @Published private(set) var loadError: String?

    /// Set to true exactly once per successful in-app purchase, before
    /// `refreshStatus()` flips `isSubscribed`. Consumed by ContentView to fire
    /// the post-trial notifications onboarding sheet, then reset.
    @Published var justPurchased = false

    private let productIDs = ["01", "02"]
    private let log = Logger(subsystem: "uk.ddbx.app", category: "subscriptions")

    init() {
        Task { [self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await refreshStatus()
                }
            }
        }
    }

    func load() async {
        await fetchProducts(attempts: 3)
        await refreshStatus()
        isLoading = false
    }

    /// User-triggered retry from the paywall.
    func reload() async {
        loadError = nil
        await fetchProducts(attempts: 2)
        await refreshStatus()
    }

    private func fetchProducts(attempts: Int) async {
        for attempt in 1...attempts {
            do {
                let loaded = try await Product.products(for: productIDs)
                let ordered = productIDs.compactMap { id in loaded.first { $0.id == id } }
                if !ordered.isEmpty {
                    products = ordered
                    loadError = nil
                    log.info("StoreKit products loaded: \(ordered.map(\.id).joined(separator: ","), privacy: .public)")
                    return
                }
                log.error("StoreKit returned 0 products (attempt \(attempt)/\(attempts)). Requested: \(self.productIDs.joined(separator: ","), privacy: .public)")
                loadError = "Subscriptions are still being prepared. This can take up to 24 hours after release."
            } catch {
                log.error("StoreKit fetch failed (attempt \(attempt)/\(attempts)): \(error.localizedDescription, privacy: .public)")
                loadError = "Couldn't reach the App Store. Check your connection and try again."
            }
            if attempt < attempts {
                let delayNs = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            justPurchased = true
            await refreshStatus()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshStatus()
    }

    #if DEBUG
    func debugUnlock() { isSubscribed = true }
    #endif

    private func refreshStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }
}
