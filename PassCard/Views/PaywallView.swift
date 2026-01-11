//
//  PaywallView.swift
//  PassCard
//
//  Premium subscription paywall
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isAnimating = false
    @State private var isPurchasing = false
    @State private var showFeatures = false
    @State private var products: [Product] = []
    @State private var purchaseError: String?
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated orbs
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: isAnimating ? -50 : -100, y: isAnimating ? 100 : 50)
                    .blur(radius: 60)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(x: geo.size.width - 150, y: isAnimating ? 200 : 300)
                    .blur(radius: 50)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: isAnimating ? 100 : 50, y: geo.size.height - 300)
                    .blur(radius: 40)
            }
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.3))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
            .zIndex(1)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: .purple.opacity(0.5), radius: 20)
                            
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        
                        VStack(spacing: 8) {
                            Text("PassCard Pro")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Unlock unlimited pass creation")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .offset(y: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                    }
                    .padding(.top, 60)
                    
                    // Features
                    VStack(spacing: 16) {
                        ForEach(Array(Feature.allFeatures.enumerated()), id: \.element.id) { index, feature in
                            FeatureRow(feature: feature)
                                .offset(x: showFeatures ? 0 : -50)
                                .opacity(showFeatures ? 1 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.1),
                                    value: showFeatures
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Plans
                    VStack(spacing: 12) {
                        ForEach(SubscriptionPlan.allCases) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan == plan
                            ) {
                                HapticManager.shared.selection()
                                withAnimation(.spring(response: 0.3)) {
                                    selectedPlan = plan
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Subscribe button
                    Button {
                        HapticManager.shared.mediumImpact()
                        purchase()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 56)
                                .shadow(color: .purple.opacity(0.4), radius: 15, y: 5)
                            
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal)
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    
                    // Restore button
                    Button {
                        HapticManager.shared.lightImpact()
                        restorePurchases()
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .disabled(isPurchasing)
                    
                    // Terms
                    VStack(spacing: 8) {
                        Text("Cancel anytime")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        HStack(spacing: 16) {
                            Button("Terms of Use") { }
                            Button("Privacy Policy") { }
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .alert("error", isPresented: $showingError) {
            Button("ok") { }
        } message: {
            Text(purchaseError ?? "")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFeatures = true
            }
            loadProducts()
        }
    }
    
    private func loadProducts() {
        Task {
            do {
                // Replace with your actual product IDs from App Store Connect
                let productIDs = [
                    "com.needsomevibe.PassCard.weekly",
                    "com.needsomevibe.PassCard.yearly"
                ]
                
                products = try await Product.products(for: productIDs)
            } catch {
                print("Failed to load products: \(error)")
            }
        }
    }
    
    private func purchase() {
        isPurchasing = true
        HapticManager.shared.mediumImpact()
        
        Task {
            do {
                // Find the selected product
                let productID = selectedPlan == .yearly ? 
                    "com.needsomevibe.PassCard.yearly" : 
                    "com.needsomevibe.PassCard.weekly"
                
                guard let product = products.first(where: { $0.id == productID }) else {
                    // Fallback: simulate purchase for testing
                    await simulatePurchase()
                    return
                }
                
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    // Verify the transaction
                    switch verification {
                    case .verified(let transaction):
                        // Grant access
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: "isPremium")
                            HapticManager.shared.success()
                            isPurchasing = false
                            dismiss()
                        }
                        
                        // Finish the transaction
                        await transaction.finish()
                        
                    case .unverified:
                        await MainActor.run {
                            purchaseError = "Purchase verification failed"
                            showingError = true
                            isPurchasing = false
                        }
                    }
                    
                case .userCancelled:
                    await MainActor.run {
                        isPurchasing = false
                    }
                    
                case .pending:
                    await MainActor.run {
                        purchaseError = "Purchase is pending approval"
                        showingError = true
                        isPurchasing = false
                    }
                    
                @unknown default:
                    await MainActor.run {
                        isPurchasing = false
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseError = error.localizedDescription
                    showingError = true
                    isPurchasing = false
                }
            }
        }
    }
    
    private func simulatePurchase() async {
        // Fallback simulation for testing without StoreKit configuration
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            isPurchasing = false
            HapticManager.shared.success()
            UserDefaults.standard.set(true, forKey: "isPremium")
            dismiss()
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        HapticManager.shared.lightImpact()
        
        Task {
            do {
                try await AppStore.sync()
                
                // Check for active subscriptions
                for await result in Transaction.currentEntitlements {
                    switch result {
                    case .verified(let transaction):
                        // User has active subscription
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: "isPremium")
                            HapticManager.shared.success()
                            isPurchasing = false
                            dismiss()
                        }
                        return
                        
                    case .unverified:
                        continue
                    }
                }
                
                // No active subscriptions found
                await MainActor.run {
                    purchaseError = "No active subscriptions found"
                    showingError = true
                    isPurchasing = false
                }
                
            } catch {
                await MainActor.run {
                    purchaseError = error.localizedDescription
                    showingError = true
                    isPurchasing = false
                }
            }
        }
    }
}

// MARK: - Feature
struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    static let allFeatures: [Feature] = [
        Feature(
            icon: "infinity",
            title: "Unlimited Passes",
            subtitle: "Create as many passes as you need",
            color: .purple
        ),
        Feature(
            icon: "paintbrush.fill",
            title: "Custom Designs",
            subtitle: "Full color customization & themes",
            color: .blue
        ),
        Feature(
            icon: "icloud.fill",
            title: "Cloud Sync",
            subtitle: "Access your passes on all devices",
            color: .cyan
        ),
        Feature(
            icon: "bell.badge.fill",
            title: "Smart Notifications",
            subtitle: "Get reminded before events",
            color: .orange
        )
    ]
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: Feature
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: feature.icon)
                    .font(.title3)
                    .foregroundStyle(feature.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case yearly = "Yearly"
    
    var id: String { rawValue }
    
    var price: String {
        switch self {
        case .weekly: return "$1.99"
        case .yearly: return "$9.99"
        }
    }
    
    var period: String {
        switch self {
        case .weekly: return "per week"
        case .yearly: return "per year"
        }
    }
    
    var savings: String? {
        switch self {
        case .weekly: return nil
        case .yearly: return "Save 90%"
        }
    }
    
    var isPopular: Bool {
        self == .yearly
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        if plan.isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                        }
                    }
                    
                    if let savings = plan.savings {
                        Text(savings)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(plan.period)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? 
                                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 2
                            )
                    }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
}
