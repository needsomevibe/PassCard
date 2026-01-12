//
//  SettingsView.swift
//  PassCard
//
//  Application settings
//

import SwiftUI
import Combine
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    @ObservedObject var storageManager: PassStorageManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showingPaywall = false
    @State private var showingClearConfirmation = false
    @State private var showingClearSuccess = false
    @State private var showingServerSettings = false
    @State private var appearAnimation = false
    
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    
    private var isPremium: Bool {
        subscriptionManager.isPremium || UserDefaults.standard.bool(forKey: "isPremium")
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                Section {
                    PremiumCard(isPremium: isPremium) {
                        HapticManager.shared.mediumImpact()
                        showingPaywall = true
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.05), value: appearAnimation)
                
                // Stats Section
                Section {
                    StatsCard(
                        passCount: storageManager.savedPasses.count,
                        isPremium: isPremium,
                        iCloudEnabled: iCloudSyncEnabled,
                        isSyncing: storageManager.isSyncing
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: appearAnimation)
                
                // iCloud Sync Section
                Section {
                    if isPremium {
                        Toggle(isOn: $iCloudSyncEnabled) {
                            SettingsRow(icon: "icloud.fill", color: .blue, title: "icloud_sync") {
                                EmptyView()
                            }
                        }
                        .onChange(of: iCloudSyncEnabled) { _, newValue in
                            HapticManager.shared.lightImpact()
                            if newValue {
                                storageManager.forceSync()
                            }
                        }
                        
                        if iCloudSyncEnabled {
                            Button {
                                HapticManager.shared.mediumImpact()
                                storageManager.forceSync()
                            } label: {
                                SettingsRow(icon: "arrow.triangle.2.circlepath", color: .green, title: "sync_now") {
                                    if storageManager.isSyncing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if let lastSync = storageManager.lastSyncDate {
                                        Text(lastSync, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(storageManager.isSyncing)
                        }
                    } else {
                        Button {
                            HapticManager.shared.mediumImpact()
                            showingPaywall = true
                        } label: {
                            SettingsRow(icon: "icloud.fill", color: .blue, title: "icloud_sync") {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text("Pro")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.yellow)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.yellow.opacity(0.15))
                                )
                            }
                        }
                    }
                } header: {
                    Text("icloud")
                } footer: {
                    if isPremium {
                        if iCloudSyncEnabled {
                            Text("icloud_sync_footer")
                        } else {
                            Text("icloud_sync_disabled_footer")
                        }
                    } else {
                        Text("icloud_sync_premium_required")
                    }
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.12), value: appearAnimation)
                
                // Preferences Section
                Section {
                    // Appearance
                    Picker(selection: $appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.icon)
                                .tag(appearance)
                        }
                    } label: {
                        SettingsRow(icon: "circle.lefthalf.filled", color: .indigo, title: "appearance") {
                            EmptyView()
                        }
                    }
                    
                    // Haptics
                    Toggle(isOn: $hapticsEnabled) {
                        SettingsRow(icon: "waveform", color: .cyan, title: "haptics") {
                            EmptyView()
                        }
                    }
                    .onChange(of: hapticsEnabled) { _, newValue in
                        HapticManager.shared.isEnabled = newValue
                        if newValue {
                            HapticManager.shared.lightImpact()
                        }
                    }
                } header: {
                    Text("preferences")
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.15), value: appearAnimation)
                
                // Developer Section (Only in Debug)
                #if DEBUG
                Section {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingServerSettings = true
                    } label: {
                        SettingsRow(icon: "server.rack", color: .gray, title: "server_settings") {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("developer")
                } footer: {
                    Text("Configure server URL for pass generation")
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.2), value: appearAnimation)
                #endif
                
                // Support Section
                Section {
                    Button {
                        HapticManager.shared.lightImpact()
                        requestReview()
                    } label: {
                        SettingsRow(icon: "star.fill", color: .yellow, title: "rate_app") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Button {
                        HapticManager.shared.lightImpact()
                        shareApp()
                    } label: {
                        SettingsRow(icon: "square.and.arrow.up.fill", color: .blue, title: "share_app") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:support@passcard.app")!) {
                        SettingsRow(icon: "envelope.fill", color: .green, title: "contact_support") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("support")
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.25), value: appearAnimation)
                
                // About Section
                Section {
                    SettingsRow(icon: "info.circle.fill", color: .blue, title: "version") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://developer.apple.com/wallet/")!) {
                        SettingsRow(icon: "wallet.pass.fill", color: .black, title: "apple_wallet_docs") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/legal/privacy/")!) {
                        SettingsRow(icon: "hand.raised.fill", color: .blue, title: "privacy_policy") {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("about")
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.3), value: appearAnimation)
                
                // Data Section
                Section {
                    Button(role: .destructive) {
                        HapticManager.shared.warning()
                        showingClearConfirmation = true
                    } label: {
                        SettingsRow(icon: "trash.fill", color: .red, title: "clear_data") {
                            EmptyView()
                        }
                    }
                } footer: {
                    Text("Removes all saved passes from the app. Passes in Apple Wallet are not affected.")
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.35), value: appearAnimation)
                
                // Footer
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("PassCard")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Made with ❤️ for Apple Wallet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.4), value: appearAnimation)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingServerSettings) {
                ServerSettingsView()
            }
            .alert("clear_all_data_title", isPresented: $showingClearConfirmation) {
                Button("cancel", role: .cancel) { }
                Button("clear_all_button", role: .destructive) {
                    let count = storageManager.savedPasses.count
                    storageManager.clearAll()
                    HapticManager.shared.success()
                    if count > 0 {
                        showingClearSuccess = true
                    }
                }
            } message: {
                Text("clear_all_data_message")
            }
            .alert("cleared_title", isPresented: $showingClearSuccess) {
                Button("ok") { }
            } message: {
                Text("cleared_message")
            }
            .onAppear {
                withAnimation {
                    appearAnimation = true
                }
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func shareApp() {
        let url = URL(string: "https://apps.apple.com/app/passcard")!
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - App Appearance
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    
    var id: String { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    let passCount: Int
    var isPremium: Bool = false
    var iCloudEnabled: Bool = true
    var isSyncing: Bool = false
    
    private var syncStatus: String {
        if !isPremium {
            return "Local"
        }
        return iCloudEnabled ? (isSyncing ? "Syncing" : "Synced") : "Local"
    }
    
    private var syncIcon: String {
        if !isPremium {
            return "iphone"
        }
        return iCloudEnabled ? (isSyncing ? "arrow.triangle.2.circlepath" : "icloud.fill") : "iphone"
    }
    
    private var syncColor: Color {
        if !isPremium {
            return .gray
        }
        return iCloudEnabled ? .blue : .gray
    }

    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(passCount)", label: "Passes", icon: "wallet.pass.fill", color: .blue)

            Divider()
                .frame(height: 40)

            StatItem(
                value: syncStatus,
                label: "iCloud",
                icon: syncIcon,
                color: syncColor,
                isAnimating: isPremium && isSyncing
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var isAnimating: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .symbolEffect(.pulse.byLayer, options: .repeating, isActive: isAnimating)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Premium Card
struct PremiumCard: View {
    let isPremium: Bool
    let action: () -> Void
    @State private var shimmer = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isPremium ? [.yellow, .orange] : [.purple, .pink, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: isPremium ? "crown.fill" : "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: shimmer)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPremium ? "PassCard Pro" : "Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(isPremium ? "Thank you for your support!" : "Unlimited passes, themes & more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !isPremium {
                    Text("GO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        if !isPremium {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.6), .pink.opacity(0.4), .blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                    }
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shimmer = true
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    @ViewBuilder let accessory: Accessory
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 30, height: 30)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            accessory
        }
    }
}

// MARK: - Server Settings View
struct ServerSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var isChecking = false
    @State private var serverStatus: ServerStatus = .unknown
    
    enum ServerStatus {
        case unknown, checking, connected, failed
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .checking: return .orange
            case .connected: return .green
            case .failed: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .unknown: return "circle"
            case .checking: return "circle.dotted"
            case .connected: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("https://your-server.com", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        
                        Image(systemName: serverStatus.icon)
                            .foregroundStyle(serverStatus.color)
                            .symbolEffect(.pulse, isActive: serverStatus == .checking)
                    }
                } header: {
                    Text("Server URL")
                } footer: {
                    Text("Enter your PassCard server URL. Use ngrok for local development.")
                }
                
                Section {
                    Button {
                        HapticManager.shared.lightImpact()
                        checkConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isChecking {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(serverURL.isEmpty || isChecking)
                    
                    Button {
                        HapticManager.shared.mediumImpact()
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(serverURL.isEmpty)
                }
                
                Section {
                    Button {
                        serverURL = "http://localhost:3000"
                        HapticManager.shared.lightImpact()
                    } label: {
                        Text("Use localhost:3000")
                    }
                    
                    Button {
                        serverURL = "https://passcard-1.onrender.com"
                        HapticManager.shared.lightImpact()
                    } label: {
                        Text("Use Render Server")
                    }
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("Localhost works only in Simulator. Use ngrok for testing on real devices.")
                }
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                serverURL = PassAPIService.shared.getServerURL()
            }
        }
    }
    
    private func checkConnection() {
        isChecking = true
        serverStatus = .checking
        
        Task {
            // Temporarily set the URL for testing
            let originalURL = PassAPIService.shared.getServerURL()
            PassAPIService.shared.setServerURL(serverURL)
            
            let isConnected = await PassAPIService.shared.healthCheck()
            
            await MainActor.run {
                isChecking = false
                if isConnected {
                    HapticManager.shared.success()
                    serverStatus = .connected
                } else {
                    HapticManager.shared.error()
                    serverStatus = .failed
                    PassAPIService.shared.setServerURL(originalURL)
                }
            }
        }
    }
    
    private func saveAndDismiss() {
        PassAPIService.shared.setServerURL(serverURL)
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    SettingsView(storageManager: PassStorageManager())
}
