import StoreKit
import WidgetKit

/// Rowbin Pro: one non-consumable in-app purchase via StoreKit 2.
@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.pocketappstudio.rowbin.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool = SharedStore.proCached
    @Published private(set) var busy = false
    @Published var message: String?
    @Published private(set) var loadFailed = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await loadProduct(); await refreshEntitlements() }
    }
    deinit { updatesTask?.cancel() }

    var priceText: String { product?.displayPrice ?? "" }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            loadFailed = product == nil
        } catch { loadFailed = true }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        setPro(owned)
    }

    private func setPro(_ v: Bool) {
        if isPro != v { isPro = v }
        if SharedStore.proCached != v { SharedStore.proCached = v; WidgetCenter.shared.reloadAllTimelines() }
    }

    /// Returns true when Pro became active.
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else { message = "The App Store isn’t reachable right now. Please try again in a moment."; return false }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let t):
                    await t.finish(); setPro(true); message = nil; return true
                case .unverified:
                    message = "The App Store couldn’t confirm this purchase. Please try Restore Purchases."
                }
            case .pending:
                message = "Your purchase is waiting for approval. Pro turns on as soon as it’s approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn’t go through. Please try again."
        }
        return false
    }

    func restore() async {
        busy = true; defer { busy = false }
        do { try await AppStore.sync() } catch { }
        await refreshEntitlements()
        message = isPro ? "Pro restored. Thank you! 🧶" : "No Rowbin Pro purchase was found for this Apple Account."
    }
}
