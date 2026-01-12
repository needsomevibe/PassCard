//
//  CreatePassView.swift
//  PassCard
//
//  Multi-step pass creation form with Apple Design style
//

import SwiftUI

struct CreatePassView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storageManager: PassStorageManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var ticket = PassTicket()
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var generatedPassData: Data?
    @State private var generatedSerialNumber: String?
    @State private var showingAddToWallet = false
    @State private var showingScanner = false
    @State private var appearAnimation = false
    @State private var showingPaywall = false
    
    private let totalSteps = 3
    
    private var isPremium: Bool {
        subscriptionManager.isPremium || UserDefaults.standard.bool(forKey: "isPremium")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator with animation
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ticket.ticketType.accentColor, ticket.ticketType.accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (Double(currentStep + 1) / Double(totalSteps)), height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Step indicators
                HStack {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(step <= currentStep ? ticket.ticketType.accentColor : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(step == currentStep ? 1.2 : 1)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                        if step < totalSteps - 1 {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                
                // Content
                TabView(selection: $currentStep) {
                    PassTypeSelectionView(ticket: $ticket, appearAnimation: appearAnimation)
                        .tag(0)
                    
                    PassDetailsFormView(ticket: $ticket)
                        .tag(1)
                    
                    PassAppearanceView(
                        ticket: $ticket,
                        showingScanner: $showingScanner,
                        showingPaywall: $showingPaywall,
                        isPremium: isPremium
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                
                // Navigation buttons
                NavigationButtonsView(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    isLoading: isLoading,
                    canProceed: canProceed,
                    accentColor: ticket.ticketType.accentColor,
                    onFinish: createPass
                )
                .padding()
            }
            .navigationTitle("new_pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                }
            }
            .alert("error", isPresented: $showingError) {
                Button("ok") { }
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showingAddToWallet) {
                if let passData = generatedPassData, let serialNumber = generatedSerialNumber {
                    AddToWalletView(
                        passData: passData,
                        serialNumber: serialNumber,
                        ticket: ticket,
                        storageManager: storageManager,
                        onDismiss: {
                            generatedPassData = nil
                            generatedSerialNumber = nil
                            dismiss()
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                BarcodeScannerView(scannedCode: $ticket.barcodeMessage)
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                PaywallView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appearAnimation = true
                }
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            return isDetailsValid
        case 2:
            return !ticket.barcodeMessage.isEmpty
        default:
            return true
        }
    }
    
    private var isDetailsValid: Bool {
        switch ticket.ticketType {
        case .eventTicket:
            return !ticket.organizationName.isEmpty && !ticket.eventName.isEmpty
        case .boardingPass:
            return !ticket.organizationName.isEmpty && 
                   ticket.passengerName?.isEmpty == false &&
                   ticket.originCode?.isEmpty == false &&
                   ticket.destinationCode?.isEmpty == false
        case .coupon:
            return !ticket.organizationName.isEmpty && ticket.couponTitle?.isEmpty == false
        case .storeCard:
            return !ticket.organizationName.isEmpty
        case .generic:
            return !ticket.organizationName.isEmpty && ticket.primaryValue?.isEmpty == false
        }
    }
    
    private func createPass() {
        HapticManager.shared.mediumImpact()
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let request = CreatePassRequest(ticket: ticket)
                let (passData, serialNumber) = try await PassAPIService.shared.createPass(request: request)
                
                await MainActor.run {
                    HapticManager.shared.success()
                    isLoading = false
                    generatedPassData = passData
                    generatedSerialNumber = serialNumber
                    showingAddToWallet = true
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
}

// MARK: - Pass Type Selection View
struct PassTypeSelectionView: View {
    @Binding var ticket: PassTicket
    let appearAnimation: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("select_pass_type")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: appearAnimation)
                
                VStack(spacing: 12) {
                    ForEach(Array(TicketType.allCases.enumerated()), id: \.element.id) { index, type in
                        PassTypeCard(
                            type: type,
                            isSelected: ticket.ticketType == type
                        ) {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ticket.ticketType = type
                            }
                        }
                        .opacity(appearAnimation ? 1 : 0)
                        .animation(
                            .easeOut(duration: 0.3)
                            .delay(Double(index) * 0.05),
                            value: appearAnimation
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Pass Type Card
struct PassTypeCard: View {
    let type: TicketType
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with glow effect
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(type.accentColor)
                            .frame(width: 56, height: 56)
                            .shadow(color: type.accentColor.opacity(0.5), radius: 12, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(type.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                    }
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : type.accentColor)
                        .scaleEffect(isSelected ? 1.1 : 1)
                }
                .animation(.spring(response: 0.3), value: isSelected)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Checkmark with animation
                ZStack {
                    Circle()
                        .stroke(isSelected ? type.accentColor : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    
                    if isSelected {
                        Circle()
                            .fill(type.accentColor)
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: isSelected ? type.accentColor.opacity(0.15) : .clear,
                        radius: 12, y: 4
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ? type.accentColor : Color(.separator).opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Pass Details Form View
struct PassDetailsFormView: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Form {
            // Organization section (common for all)
            Section {
                TextField("organization_name", text: $ticket.organizationName)
            }
            
            // Type-specific fields
            switch ticket.ticketType {
            case .eventTicket:
                EventTicketFields(ticket: $ticket)
            case .boardingPass:
                BoardingPassFields(ticket: $ticket)
            case .coupon:
                CouponFields(ticket: $ticket)
            case .storeCard:
                StoreCardFields(ticket: $ticket)
            case .generic:
                GenericPassFields(ticket: $ticket)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Event Ticket Fields
struct EventTicketFields: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Section("basic_info") {
            TextField("event_name", text: $ticket.eventName)
            TextField("venue", text: $ticket.venueName)
            TextField("address", text: $ticket.venueAddress)
        }
        
        Section("date") {
            DatePicker("date", selection: $ticket.eventDate, displayedComponents: .date)
            DatePicker("time", selection: $ticket.eventTime, displayedComponents: .hourAndMinute)
        }
        
        Section("seating") {
            TextField("section", text: Binding(
                get: { ticket.seatSection ?? "" },
                set: { ticket.seatSection = $0.isEmpty ? nil : $0 }
            ))
            TextField("row", text: Binding(
                get: { ticket.seatRow ?? "" },
                set: { ticket.seatRow = $0.isEmpty ? nil : $0 }
            ))
            TextField("seat", text: Binding(
                get: { ticket.seatNumber ?? "" },
                set: { ticket.seatNumber = $0.isEmpty ? nil : $0 }
            ))
        }
        
        Section {
            TextField("ticket_holder", text: Binding(
                get: { ticket.ticketHolder ?? "" },
                set: { ticket.ticketHolder = $0.isEmpty ? nil : $0 }
            ))
        }
    }
}

// MARK: - Boarding Pass Fields
struct BoardingPassFields: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Section("flight_info") {
            TextField("passenger_name", text: Binding(
                get: { ticket.passengerName ?? "" },
                set: { ticket.passengerName = $0.isEmpty ? nil : $0 }
            ))
            TextField("flight_number", text: Binding(
                get: { ticket.flightNumber ?? "" },
                set: { ticket.flightNumber = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.characters)
        }
        
        Section("route") {
            HStack {
                VStack(alignment: .leading) {
                    Text("origin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("airport_code", text: Binding(
                        get: { ticket.originCode ?? "" },
                        set: { ticket.originCode = $0.isEmpty ? nil : $0.uppercased() }
                    ))
                    .textInputAutocapitalization(.characters)
                    .font(.title2.bold())
                    
                    TextField("city", text: Binding(
                        get: { ticket.originCity ?? "" },
                        set: { ticket.originCity = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.caption)
                }
                
                Spacer()
                
                Image(systemName: "airplane")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("airport_code", text: Binding(
                        get: { ticket.destinationCode ?? "" },
                        set: { ticket.destinationCode = $0.isEmpty ? nil : $0.uppercased() }
                    ))
                    .textInputAutocapitalization(.characters)
                    .font(.title2.bold())
                    .multilineTextAlignment(.trailing)
                    
                    TextField("city", text: Binding(
                        get: { ticket.destinationCity ?? "" },
                        set: { ticket.destinationCity = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        
        Section("date") {
            DatePicker("departure", selection: Binding(
                get: { ticket.departureTime ?? Date() },
                set: { ticket.departureTime = $0 }
            ))
        }
        
        Section("boarding_info") {
            TextField("gate", text: Binding(
                get: { ticket.gate ?? "" },
                set: { ticket.gate = $0.isEmpty ? nil : $0 }
            ))
            TextField("boarding_group", text: Binding(
                get: { ticket.boardingGroup ?? "" },
                set: { ticket.boardingGroup = $0.isEmpty ? nil : $0 }
            ))
            TextField("seat", text: Binding(
                get: { ticket.seatNumber ?? "" },
                set: { ticket.seatNumber = $0.isEmpty ? nil : $0 }
            ))
            TextField("class", text: Binding(
                get: { ticket.seatClass ?? "" },
                set: { ticket.seatClass = $0.isEmpty ? nil : $0 }
            ))
        }
        
        Section {
            TextField("confirmation_code", text: Binding(
                get: { ticket.confirmationCode ?? "" },
                set: { ticket.confirmationCode = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.characters)
        }
    }
}

// MARK: - Coupon Fields
struct CouponFields: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Section("offer_details") {
            TextField("coupon_title", text: Binding(
                get: { ticket.couponTitle ?? "" },
                set: { ticket.couponTitle = $0.isEmpty ? nil : $0 }
            ))
            TextField("discount", text: Binding(
                get: { ticket.discountAmount ?? "" },
                set: { ticket.discountAmount = $0.isEmpty ? nil : $0 }
            ))
            TextField("promo_code", text: Binding(
                get: { ticket.promoCode ?? "" },
                set: { ticket.promoCode = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.characters)
        }
        
        Section {
            TextField("store_name", text: Binding(
                get: { ticket.storeName ?? "" },
                set: { ticket.storeName = $0.isEmpty ? nil : $0 }
            ))
            DatePicker("expiration_date", selection: Binding(
                get: { ticket.expirationDate ?? Date().addingTimeInterval(30*24*60*60) },
                set: { ticket.expirationDate = $0 }
            ), displayedComponents: .date)
        }
        
        Section("terms") {
            TextField("terms", text: Binding(
                get: { ticket.termsAndConditions ?? "" },
                set: { ticket.termsAndConditions = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(3...6)
        }
    }
}

// MARK: - Store Card Fields
struct StoreCardFields: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Section("card_details") {
            TextField("cardholder_name", text: Binding(
                get: { ticket.cardholderName ?? "" },
                set: { ticket.cardholderName = $0.isEmpty ? nil : $0 }
            ))
            TextField("membership_level", text: Binding(
                get: { ticket.membershipLevel ?? "" },
                set: { ticket.membershipLevel = $0.isEmpty ? nil : $0 }
            ))
            TextField("points_balance", text: Binding(
                get: { ticket.pointsBalance ?? "" },
                set: { ticket.pointsBalance = $0.isEmpty ? nil : $0 }
            ))
            .keyboardType(.numberPad)
        }
        
        Section {
            DatePicker("member_since", selection: Binding(
                get: { ticket.memberSince ?? Date() },
                set: { ticket.memberSince = $0 }
            ), displayedComponents: .date)
        }
    }
}

// MARK: - Generic Pass Fields
struct GenericPassFields: View {
    @Binding var ticket: PassTicket
    
    var body: some View {
        Section("primary_field") {
            TextField("label", text: Binding(
                get: { ticket.primaryLabel ?? "" },
                set: { ticket.primaryLabel = $0.isEmpty ? nil : $0 }
            ))
            TextField("value", text: Binding(
                get: { ticket.primaryValue ?? "" },
                set: { ticket.primaryValue = $0.isEmpty ? nil : $0 }
            ))
        }
        
        Section("secondary_field") {
            TextField("label", text: Binding(
                get: { ticket.secondaryLabel ?? "" },
                set: { ticket.secondaryLabel = $0.isEmpty ? nil : $0 }
            ))
            TextField("value", text: Binding(
                get: { ticket.secondaryValue ?? "" },
                set: { ticket.secondaryValue = $0.isEmpty ? nil : $0 }
            ))
        }
    }
}

// MARK: - Pass Appearance View
struct PassAppearanceView: View {
    @Binding var ticket: PassTicket
    @Binding var showingScanner: Bool
    @Binding var showingPaywall: Bool
    let isPremium: Bool
    
    var body: some View {
        Form {
            // Color presets
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(PassColorPreset.presets.enumerated()), id: \.element.id) { index, preset in
                            ColorPresetButton(
                                preset: preset,
                                isLocked: !isPremium && index > 0,
                                action: {
                                    if !isPremium && index > 0 {
                                        HapticManager.shared.warning()
                                        showingPaywall = true
                                    } else {
                                        withAnimation {
                                            ticket.backgroundColor = preset.backgroundColor
                                            ticket.foregroundColor = preset.foregroundColor
                                            ticket.labelColor = preset.labelColor
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } header: {
                Text("color_scheme")
            } footer: {
                if !isPremium {
                    Text("color_scheme_premium_footer")
                        .font(.caption)
                }
            }
            // Barcode
            Section("barcode") {
                Picker("barcode_format", selection: $ticket.barcodeFormat) {
                    ForEach(BarcodeFormat.allCases) { format in
                        Label {
                            Text(format.displayName)
                        } icon: {
                            Image(systemName: format.icon)
                        }
                        .tag(format)
                    }
                }
                
                HStack {
                    TextField("barcode_data", text: $ticket.barcodeMessage)
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        HapticManager.shared.lightImpact()
                        showingScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.lightImpact()
                        ticket.barcodeMessage = UUID().uuidString
                    } label: {
                        Label("generate_id", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            
            // Preview
            Section("preview") {
                PassPreviewCard(ticket: ticket)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Color Preset Button
struct ColorPresetButton: View {
    let preset: PassColorPreset
    var isLocked: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: preset.backgroundColor))
                        .frame(width: 56, height: 40)
                        .overlay {
                            Text("Aa")
                                .font(.headline)
                                .foregroundColor(Color(hex: preset.foregroundColor))
                                .opacity(isLocked ? 0.3 : 1)
                        }
                    
                    if isLocked {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                    }
                }

                Text(preset.name)
                    .font(.caption2)
                    .foregroundStyle(isLocked ? .tertiary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pass Preview Card
struct PassPreviewCard: View {
    let ticket: PassTicket
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(ticket.organizationName.isEmpty ? "Organization" : ticket.organizationName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: ticket.foregroundColor))
                
                Spacer()
                
                Image(systemName: ticket.ticketType.icon)
                    .foregroundColor(Color(hex: ticket.foregroundColor))
            }
            
            // Main content
            Text(ticket.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: ticket.foregroundColor))
                .multilineTextAlignment(.center)
            
            // Barcode preview
            if !ticket.barcodeMessage.isEmpty {
                BarcodeView(content: ticket.barcodeMessage, format: ticket.barcodeFormat)
                    .frame(height: ticket.barcodeFormat == .qr ? 80 : 50)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(hex: ticket.backgroundColor))
        .cornerRadius(16)
        .padding()
    }
}

// MARK: - Navigation Buttons View
struct NavigationButtonsView: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let isLoading: Bool
    let canProceed: Bool
    let accentColor: Color
    let onFinish: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            if currentStep > 0 {
                Button {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                        Text("back")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Next/Create button
            Button {
                if currentStep < totalSteps - 1 {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    onFinish()
                }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            if currentStep < totalSteps - 1 {
                                Text("next")
                                Image(systemName: "chevron.right")
                                    .font(.body.bold())
                            } else {
                                Image(systemName: "sparkles")
                                Text("create_pass")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .disabled(!canProceed || isLoading)
            .shadow(color: canProceed ? accentColor.opacity(0.3) : .clear, radius: 10, y: 5)
            .animation(.easeOut(duration: 0.2), value: canProceed)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
    }
}

// MARK: - Preview
#Preview {
    CreatePassView(storageManager: PassStorageManager())
}
