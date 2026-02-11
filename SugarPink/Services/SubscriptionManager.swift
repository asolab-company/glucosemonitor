import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPremiumUnlocked: Bool = false
    
    private let subscriptionProductIDs: Set<String> = Set(AppConstants.Subscription.allIDs)
    
    private init() {
        Task { await refreshSubscriptionStatus() }
    }
    
    func refreshSubscriptionStatus() async {
        var hasActiveEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil,
               subscriptionProductIDs.contains(transaction.productID) {
                hasActiveEntitlement = true
                break
            }
        }
        isPremiumUnlocked = hasActiveEntitlement
    }
    
    func purchase(productId: String) async {
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else { return }
            
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    isPremiumUnlocked = true
                    await transaction.finish()
                case .unverified:
                    break
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase error: \(error)")
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            print("Restore error: \(error)")
        }
    }
}

