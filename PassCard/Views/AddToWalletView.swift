//
//  AddToWalletView.swift
//  PassCard
//
//  Screen for adding pass to Apple Wallet
//

import SwiftUI
import PassKit

struct AddToWalletView: View {
    @Environment(\.dismiss) var dismiss
    
    let passData: Data
    let serialNumber: String
    let ticket: PassTicket
    @ObservedObject var storageManager: PassStorageManager
    let onDismiss: () -> Void
    
    @State private var isAddingToWallet = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var addedSuccessfully = false
    @State private var appearAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                if addedSuccessfully {
                    ConfettiView()
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Success animation
                    ZStack {
                        // Pulse rings
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    addedSuccessfully ? Color.green.opacity(0.3) : ticket.ticketType.accentColor.opacity(0.2),
                                    lineWidth: 2
                                )
                                .frame(width: 140 + CGFloat(i * 30), height: 140 + CGFloat(i * 30))
                                .scaleEffect(appearAnimation ? 1.3 : 0.8)
                                .opacity(appearAnimation ? 0 : 0.8)
                                .animation(
                                    .easeOut(duration: 2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                    value: appearAnimation
                                )
                        }
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: addedSuccessfully ?
                                        [.green, .green.opacity(0.7)] :
                                        [ticket.ticketType.accentColor, ticket.ticketType.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .shadow(
                                color: addedSuccessfully ? .green.opacity(0.4) : ticket.ticketType.accentColor.opacity(0.4),
                                radius: 20
                            )
                        
                        Image(systemName: addedSuccessfully ? "checkmark" : "wallet.pass.fill")
                            .font(.system(size: addedSuccessfully ? 50 : 64, weight: .medium))
                            .foregroundStyle(.white)
                            .scaleEffect(addedSuccessfully ? 1.2 : 1)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: addedSuccessfully)
                    }
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .opacity(appearAnimation ? 1 : 0)
                    
                    // Text
                    VStack(spacing: 12) {
                        Text(addedSuccessfully ? "pass_added" : "pass_created")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        
                        Text(ticket.displayName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.1), value: appearAnimation)
                    
                    // Mini preview
                    PassMiniPreview(ticket: ticket)
                        .padding(.horizontal, 40)
                        .scaleEffect(appearAnimation ? 1 : 0.9)
                        .opacity(appearAnimation ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.2), value: appearAnimation)
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 16) {
                        if !addedSuccessfully {
                            Button {
                                addToWallet()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "wallet.pass.fill")
                                        .font(.title3)
                                    Text("add_to_wallet")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .disabled(isAddingToWallet)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            .scaleEffect(appearAnimation ? 1 : 0.9)
                            .opacity(appearAnimation ? 1 : 0)
                            .animation(.spring(response: 0.5).delay(0.3), value: appearAnimation)
                        }
                        
                        Button {
                            HapticManager.shared.lightImpact()
                            sharePass()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("share")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .scaleEffect(appearAnimation ? 1 : 0.9)
                        .opacity(appearAnimation ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.35), value: appearAnimation)
                        
                        Button(addedSuccessfully ? "done" : "skip") {
                            HapticManager.shared.lightImpact()
                            saveAndDismiss()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .opacity(appearAnimation ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.4), value: appearAnimation)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.lightImpact()
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("error", isPresented: $showingError) {
                Button("ok") { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appearAnimation = true
                }
            }
        }
    }
    
    private func addToWallet() {
        // Prevent multiple calls
        guard !addedSuccessfully && !isAddingToWallet else { return }
        
        HapticManager.shared.mediumImpact()
        isAddingToWallet = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot access interface"
            showingError = true
            isAddingToWallet = false
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        WalletService.shared.addPassToWallet(data: passData, from: topVC) { [self] result in
            DispatchQueue.main.async {
                // Prevent state updates if already succeeded
                guard !addedSuccessfully else {
                    isAddingToWallet = false
                    return
                }
                
                isAddingToWallet = false
                
                switch result {
                case .success:
                    handleSuccess()
                    
                case .failure(let error):
                    if case .passAlreadyExists = error {
                        handleSuccess()
                    } else {
                        HapticManager.shared.error()
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    
    private func handleSuccess() {
        HapticManager.shared.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            addedSuccessfully = true
        }
        
        // Save pass
        var savedPass = SavedPass(from: ticket, serialNumber: serialNumber)
        savedPass.isAddedToWallet = true
        storageManager.savePass(savedPass)
        
        // Auto-close after showing success animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
            onDismiss()
        }
    }
    
    private func sharePass() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        do {
            try WalletService.shared.sharePass(
                data: passData,
                filename: ticket.displayName,
                from: topVC
            )
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func saveAndDismiss() {
        if !addedSuccessfully {
            let savedPass = SavedPass(from: ticket, serialNumber: serialNumber)
            storageManager.savePass(savedPass)
        }
        dismiss()
        onDismiss()
    }
}

// MARK: - Pass Mini Preview
struct PassMiniPreview: View {
    let ticket: PassTicket
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(ticket.organizationName)
                    .font(.caption)
                    .foregroundColor(Color(hex: ticket.labelColor))
                Spacer()
                Image(systemName: ticket.ticketType.icon)
                    .foregroundColor(Color(hex: ticket.foregroundColor))
            }
            
            Text(ticket.displayName)
                .font(.headline)
                .foregroundColor(Color(hex: ticket.foregroundColor))
                .multilineTextAlignment(.center)
            
            HStack {
                Text(ticket.formattedDate)
                if !ticket.formattedTime.isEmpty {
                    Text("•")
                    Text(ticket.formattedTime)
                }
            }
            .font(.caption)
            .foregroundColor(Color(hex: ticket.labelColor))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: ticket.backgroundColor))
                .shadow(color: Color(hex: ticket.backgroundColor).opacity(0.4), radius: 20, y: 10)
        )
        .rotation3DEffect(
            .degrees(isAnimating ? 0 : 10),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan]
        
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                position: CGPoint(x: size.width / 2, y: size.height / 3),
                opacity: 1
            )
            particles.append(particle)
        }
        
        // Animate particles
        for i in particles.indices {
            let randomX = CGFloat.random(in: -150...150)
            let randomY = CGFloat.random(in: 200...500)
            let duration = Double.random(in: 1.5...2.5)
            
            withAnimation(.easeOut(duration: duration)) {
                particles[i].position.x += randomX
                particles[i].position.y += randomY
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}

// MARK: - Preview
#Preview {
    AddToWalletView(
        passData: Data(),
        serialNumber: "TEST-001",
        ticket: PassTicket(
            ticketType: .eventTicket,
            organizationName: "Concert Agency",
            eventName: "Example Concert"
        ),
        storageManager: PassStorageManager(),
        onDismiss: { }
    )
}
