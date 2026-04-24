import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private static let webPremiumFlagKey = "sugarpink_web_premium_unlocked"

    @Published var isPremiumUnlocked: Bool = false
    @Published var errorText: String?

    private let subscriptionProductIDs: Set<String> = Set(AppConstants.Subscription.allIDs)
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = observeTransactions()
        Task { await refreshSubscriptionStatus() }
    }

    deinit {
        updateTask?.cancel()
    }

    func unlockPremiumFromWebCheckout() {
        UserDefaults.standard.set(true, forKey: Self.webPremiumFlagKey)
        isPremiumUnlocked = true
    }

    func refreshSubscriptionStatus() async {
        var hasActiveEntitlement = false
        for await result in Transaction.currentEntitlements {
            if
                case .verified(let transaction) = result,
                transaction.revocationDate == nil,
                subscriptionProductIDs.contains(transaction.productID)
            {
                hasActiveEntitlement = true
                break
            }
        }
        isPremiumUnlocked = hasActiveEntitlement || hasWebPremiumOverride()
    }

    func purchase(productId: String) async -> Bool {
        errorText = nil

        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                errorText = "Product not found."
                return false
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    isPremiumUnlocked = true
                    await transaction.finish()
                    AppsFlyerService.shared.trackSubscription(productID: productId)
                    return true
                case .unverified:
                    errorText = "Purchase verification failed."
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorText = error.localizedDescription
        }

        return false
    }

    func restorePurchases() async -> Bool {
        errorText = nil
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            return isPremiumUnlocked
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func hasWebPremiumOverride() -> Bool {
        UserDefaults.standard.bool(forKey: Self.webPremiumFlagKey)
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshSubscriptionStatus()
            }
        }
    }
}
