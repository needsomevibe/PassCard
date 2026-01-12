//
//  ContentView.swift
//  PassCard
//
//  Main screen with passes list
//

import SwiftUI

struct ContentView: View {
    @StateObject private var storageManager = PassStorageManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingCreatePass = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var animateList = false
    @State private var selectedFilter: PassFilter = .all
    
    private let freePassLimit = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !storageManager.savedPasses.isEmpty {
                    FilterBar(selectedFilter: $selectedFilter)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Group {
                    if storageManager.savedPasses.isEmpty {
                        EmptyStateView(showingCreatePass: $showingCreatePass)
                    } else {
                        PassesListView(
                            storageManager: storageManager,
                            showingCreatePass: $showingCreatePass,
                            animateList: animateList,
                            selectedFilter: selectedFilter
                        )
                    }
                }
            }
            .navigationTitle("PassCard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.lightImpact()
                        handleCreatePass()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingCreatePass) {
                CreatePassView(storageManager: storageManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(storageManager: storageManager)
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                PaywallView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    animateList = true
                }
            }
        }
    }
    
    private var isPremium: Bool {
        subscriptionManager.isPremium || UserDefaults.standard.bool(forKey: "isPremium")
    }
    
    private func handleCreatePass() {
        if isPremium || storageManager.savedPasses.count < freePassLimit {
            showingCreatePass = true
        } else {
            showingPaywall = true
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Binding var showingCreatePass: Bool
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                // Pulse rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3 - Double(i) * 0.1), lineWidth: 1)
                        .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            .easeOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.4),
                            value: pulseAnimation
                        )
                }
                
                Image(systemName: "wallet.pass")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0)
            }
            
            VStack(spacing: 8) {
                Text("empty_state_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text("empty_state_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            .animation(.easeOut(duration: 0.5).delay(0.2), value: isAnimating)
            
            Button {
                HapticManager.shared.mediumImpact()
                showingCreatePass = true
            } label: {
                Label("create_pass", systemImage: "plus")
                    .font(.headline)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: isAnimating)
            
            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
            pulseAnimation = true
        }
    }
}

// MARK: - Filter Bar
struct FilterBar: View {
    @Binding var selectedFilter: PassFilter
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PassFilter.allCases) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        animation: animation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            HapticManager.shared.lightImpact()
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let filter: PassFilter
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter != .all {
                    Image(systemName: filter.icon)
                        .font(.subheadline)
                }
                
                Text(filter.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(filter.color.gradient)
                        .matchedGeometryEffect(id: "filter_background", in: animation)
                } else {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pass Filter
enum PassFilter: String, CaseIterable, Identifiable {
    case all
    case eventTicket
    case boardingPass
    case coupon
    case storeCard
    case generic
    
    var id: String { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .all: return "filter_all"
        case .eventTicket: return "pass_type_event"
        case .boardingPass: return "pass_type_boarding"
        case .coupon: return "pass_type_coupon"
        case .storeCard: return "pass_type_store"
        case .generic: return "pass_type_generic"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .eventTicket: return "ticket.fill"
        case .boardingPass: return "airplane"
        case .coupon: return "tag.fill"
        case .storeCard: return "creditcard.fill"
        case .generic: return "rectangle.on.rectangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .accentColor
        case .eventTicket: return .purple
        case .boardingPass: return .blue
        case .coupon: return .orange
        case .storeCard: return .green
        case .generic: return .gray
        }
    }
    
    func matches(_ ticketType: TicketType) -> Bool {
        switch self {
        case .all: return true
        case .eventTicket: return ticketType == .eventTicket
        case .boardingPass: return ticketType == .boardingPass
        case .coupon: return ticketType == .coupon
        case .storeCard: return ticketType == .storeCard
        case .generic: return ticketType == .generic
        }
    }
}

// MARK: - Passes List View
struct PassesListView: View {
    @ObservedObject var storageManager: PassStorageManager
    @Binding var showingCreatePass: Bool
    let animateList: Bool
    let selectedFilter: PassFilter
    
    var filteredPasses: [SavedPass] {
        if selectedFilter == .all {
            return storageManager.savedPasses
        }
        return storageManager.savedPasses.filter { selectedFilter.matches($0.ticketType) }
    }
    
    var body: some View {
        Group {
            if filteredPasses.isEmpty {
                EmptyFilterStateView(filter: selectedFilter)
            } else {
                List {
                    ForEach(Array(filteredPasses.enumerated()), id: \.element.id) { index, pass in
                        NavigationLink {
                            PassDetailView(pass: pass, storageManager: storageManager)
                        } label: {
                            PassRowView(pass: pass)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                    .onDelete { offsets in
                        HapticManager.shared.mediumImpact()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            let passesToDelete = offsets.map { filteredPasses[$0] }
                            passesToDelete.forEach { storageManager.deletePass($0) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFilter)
    }
}

// MARK: - Empty Filter State View
struct EmptyFilterStateView: View {
    let filter: PassFilter
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: filter.icon)
                .font(.system(size: 60))
                .foregroundStyle(filter.color.gradient)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("no_passes_filter")
                    .font(.headline)
                
                Text(filter.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Pass Row View
struct PassRowView: View {
    let pass: SavedPass
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with gradient
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .frame(width: 50, height: 50)
                
                Image(systemName: pass.ticketType.icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(pass.eventName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(pass.organizationName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if pass.isAddedToWallet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Date
            Text(pass.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
