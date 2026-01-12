//
//  SubscriptionManager.swift
//  PassCard
//
//  Manages StoreKit 2 subscriptions
//

import Foundation
import StoreKit

// MARK: - Product IDs
enum SubscriptionProductID: String, CaseIterable {
    case weekly = "WEEK"
    case yearly = "YEARLY"
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var isLoading = false
    
    // MARK: - Computed Properties
    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }
    
    var weeklyProduct: Product? {
        products.first { $0.id == SubscriptionProductID.weekly.rawValue }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProductID.yearly.rawValue }
    }
    
    // MARK: - Private
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Init
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check status on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        
        do {
            let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products")
            
            for product in products {
                print("  - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Finish the transaction
            await transaction.finish()
            
            HapticManager.shared.success()
            print("✅ Purchase successful: \(product.id)")
            return true
            
        case .userCancelled:
            print("⚠️ User cancelled purchase")
            return false
            
        case .pending:
            print("⏳ Purchase pending")
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this is one of our subscription products
                if SubscriptionProductID.allCases.map({ $0.rawValue }).contains(transaction.productID) {
                    hasActiveSubscription = true
                    print("✅ Active subscription found: \(transaction.productID)")
                    break
                }
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }
        
        subscriptionStatus = hasActiveSubscription ? .subscribed : .notSubscribed
        
        // Also update UserDefaults for quick access
        UserDefaults.standard.set(hasActiveSubscription, forKey: "isPremium")
        
        print("📊 Subscription status: \(subscriptionStatus)")
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    await self.updateSubscriptionStatus()
                    
                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus {
    case unknown
    case notSubscribed
    case subscribed
}

// MARK: - Subscription Error
enum SubscriptionError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Could not verify your purchase"
        case .purchaseFailed:
            return "Purchase failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}
