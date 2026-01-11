//
//  PassDetailView.swift
//  PassCard
//
//  Detailed view for a saved pass
//

import SwiftUI

struct PassDetailView: View {
    @State var pass: SavedPass
    @ObservedObject var storageManager: PassStorageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var passData: Data?
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pass Card
                PassInfoCard(pass: pass)
                    .scaleEffect(appearAnimation ? 1 : 0.9)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appearAnimation)
                
                // Quick Actions
                HStack(spacing: 16) {
                    ActionButton(
                        title: "Edit",
                        icon: "pencil",
                        color: .orange
                    ) {
                        HapticManager.shared.mediumImpact()
                        showingEditSheet = true
                    }
                    
                    ActionButton(
                        title: pass.isAddedToWallet ? "Refresh" : "add_to_wallet",
                        icon: "wallet.pass.fill",
                        color: .black,
                        isLoading: isLoading
                    ) {
                        HapticManager.shared.mediumImpact()
                        redownloadPass()
                    }
                }
                .padding(.horizontal)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: appearAnimation)
                
                // Share button
                ActionButton(
                    title: "share",
                    icon: "square.and.arrow.up",
                    color: .blue
                ) {
                    HapticManager.shared.lightImpact()
                    sharePass()
                }
                .padding(.horizontal)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.15), value: appearAnimation)
                
                // Info Section
                VStack(spacing: 16) {
                    InfoSection(title: "Information") {
                        InfoRow(icon: "number", label: "Serial Number", value: pass.serialNumber, isMonospaced: true)
                        InfoRow(icon: pass.ticketType.icon, label: "Type", value: pass.ticketType.displayName)
                        InfoRow(icon: "calendar", label: "Created", value: pass.formattedCreatedAt)
                    }
                }
                .padding(.horizontal)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.2), value: appearAnimation)
                
                // Delete button
                Button(role: .destructive) {
                    HapticManager.shared.warning()
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("delete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.25), value: appearAnimation)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(pass.eventName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("error", isPresented: $showingError) {
            Button("ok") { }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete this pass?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) {
                deletePass()
            }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("This will remove the pass from the app. If it's in Wallet, remove it manually.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPassView(pass: pass, storageManager: storageManager) { newPassData, newSerialNumber in
                // Update local pass data
                passData = newPassData
                // Refresh the displayed pass
                if let index = storageManager.savedPasses.firstIndex(where: { $0.id == pass.id }) {
                    pass = storageManager.savedPasses[index]
                }
                // Offer to add to wallet
                addToWallet(data: newPassData)
            }
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
    }
    
    private func redownloadPass() {
        isLoading = true
        
        Task {
            do {
                let data = try await PassAPIService.shared.getPass(serialNumber: pass.serialNumber)
                
                await MainActor.run {
                    isLoading = false
                    passData = data
                    addToWallet(data: data)
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func addToWallet(data: Data) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        WalletService.shared.addPassToWallet(data: data, from: topVC) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    HapticManager.shared.success()
                    var updatedPass = pass
                    updatedPass.isAddedToWallet = true
                    storageManager.updatePass(updatedPass)
                case .failure(let error):
                    if case .passAlreadyExists = error {
                        HapticManager.shared.success()
                    } else {
                        HapticManager.shared.error()
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    
    private func sharePass() {
        guard let data = passData else {
            redownloadAndShare()
            return
        }
        share(data: data)
    }
    
    private func redownloadAndShare() {
        isLoading = true
        
        Task {
            do {
                let data = try await PassAPIService.shared.getPass(serialNumber: pass.serialNumber)
                
                await MainActor.run {
                    isLoading = false
                    passData = data
                    share(data: data)
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func share(data: Data) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        do {
            try WalletService.shared.sharePass(data: data, filename: pass.eventName, from: topVC)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func deletePass() {
        HapticManager.shared.mediumImpact()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            storageManager.deletePass(pass)
        }
        dismiss()
    }
}

// MARK: - Pass Info Card
struct PassInfoCard: View {
    let pass: SavedPass
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                // Glow
                Circle()
                    .fill(Color(hex: pass.backgroundColor))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .opacity(0.5)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: pass.backgroundColor),
                                Color(hex: pass.backgroundColor).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: Color(hex: pass.backgroundColor).opacity(0.4), radius: 15, y: 8)
                
                Image(systemName: pass.ticketType.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .scaleEffect(isAnimating ? 1 : 0.8)
            
            // Info
            VStack(spacing: 8) {
                Text(pass.eventName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(pass.organizationName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Details
            HStack(spacing: 20) {
                if !pass.formattedDate.isEmpty {
                    Label(pass.formattedDate, systemImage: "calendar")
                }
                
                if !pass.venueName.isEmpty {
                    Label(pass.venueName, systemImage: "mappin")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Wallet status
            if pass.isAddedToWallet {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("in_wallet")
                }
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(color == .black ? .white : color)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundColor(color == .black ? .white : .white)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Info Section
struct InfoSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Info Row
struct InfoRow<V: View>: View {
    let icon: String
    let label: String
    let isMonospaced: Bool
    let valueView: V
    
    init(icon: String, label: String, value: String, isMonospaced: Bool = false) where V == Text {
        self.icon = icon
        self.label = label
        self.isMonospaced = isMonospaced
        self.valueView = Text(value)
    }
    
    init(icon: String, label: String, value: LocalizedStringKey, isMonospaced: Bool = false) where V == Text {
        self.icon = icon
        self.label = label
        self.isMonospaced = isMonospaced
        self.valueView = Text(value)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.primary)
            
            Spacer()
            
            valueView
                .font(isMonospaced ? .system(.caption, design: .monospaced) : .body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PassDetailView(
            pass: SavedPass(
                from: PassTicket(
                    ticketType: .eventTicket,
                    organizationName: "Concert Agency",
                    backgroundColor: "#007AFF",
                    eventName: "Example Concert",
                    venueName: "Madison Square Garden"
                ),
                serialNumber: "PASS-2024-001234"
            ),
            storageManager: PassStorageManager()
        )
    }
}
