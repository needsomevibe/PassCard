//
//  EditPassView.swift
//  PassCard
//
//  Edit existing pass
//

import SwiftUI

struct EditPassView: View {
    @Environment(\.dismiss) var dismiss
    
    let pass: SavedPass
    @ObservedObject var storageManager: PassStorageManager
    let onUpdate: (Data, String) -> Void
    
    @State private var ticket: PassTicket
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(pass: SavedPass, storageManager: PassStorageManager, onUpdate: @escaping (Data, String) -> Void) {
        self.pass = pass
        self.storageManager = storageManager
        self.onUpdate = onUpdate
        _ticket = State(initialValue: PassTicket(from: pass))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Organization
                Section {
                    TextField("organization_name", text: $ticket.organizationName)
                }
                
                // Type-specific fields
                switch ticket.ticketType {
                case .eventTicket:
                    EditEventFields(ticket: $ticket)
                case .boardingPass:
                    EditBoardingFields(ticket: $ticket)
                case .coupon:
                    EditCouponFields(ticket: $ticket)
                case .storeCard:
                    EditStoreCardFields(ticket: $ticket)
                case .generic:
                    EditGenericFields(ticket: $ticket)
                }
                
                // Appearance
                Section("appearance") {
                    ColorPicker("background_color", selection: Binding(
                        get: { Color(hex: ticket.backgroundColor) },
                        set: { ticket.backgroundColor = $0.toHex() }
                    ))
                    ColorPicker("text_color", selection: Binding(
                        get: { Color(hex: ticket.foregroundColor) },
                        set: { ticket.foregroundColor = $0.toHex() }
                    ))
                    ColorPicker("label_color", selection: Binding(
                        get: { Color(hex: ticket.labelColor) },
                        set: { ticket.labelColor = $0.toHex() }
                    ))
                }
                
                // Barcode
                Section("barcode") {
                    Picker("barcode_format", selection: $ticket.barcodeFormat) {
                        ForEach(BarcodeFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    TextField("barcode_data", text: $ticket.barcodeMessage)
                        .textInputAutocapitalization(.never)
                }
                
                // Preview
                Section("preview") {
                    PassPreviewCard(ticket: ticket)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.shared.mediumImpact()
                        updatePass()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .alert("error", isPresented: $showingError) {
                Button("ok") { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var isValid: Bool {
        !ticket.organizationName.isEmpty && !ticket.barcodeMessage.isEmpty
    }
    
    private func updatePass() {
        isLoading = true
        
        Task {
            do {
                let request = CreatePassRequest(ticket: ticket)
                let (passData, serialNumber) = try await PassAPIService.shared.updatePass(
                    serialNumber: pass.serialNumber,
                    request: request
                )
                
                await MainActor.run {
                    HapticManager.shared.success()
                    isLoading = false
                    
                    // Update saved pass
                    var updatedPass = SavedPass(from: ticket, serialNumber: serialNumber)
                    updatedPass.isAddedToWallet = pass.isAddedToWallet
                    updatedPass.createdAt = pass.createdAt
                    storageManager.updatePass(updatedPass)
                    
                    onUpdate(passData, serialNumber)
                    dismiss()
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

// MARK: - Edit Event Fields
struct EditEventFields: View {
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

// MARK: - Edit Boarding Fields
struct EditBoardingFields: View {
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
            TextField("origin", text: Binding(
                get: { ticket.originCode ?? "" },
                set: { ticket.originCode = $0.isEmpty ? nil : $0.uppercased() }
            ))
            .textInputAutocapitalization(.characters)
            
            TextField("destination", text: Binding(
                get: { ticket.destinationCode ?? "" },
                set: { ticket.destinationCode = $0.isEmpty ? nil : $0.uppercased() }
            ))
            .textInputAutocapitalization(.characters)
        }
        
        Section("boarding_info") {
            TextField("gate", text: Binding(
                get: { ticket.gate ?? "" },
                set: { ticket.gate = $0.isEmpty ? nil : $0 }
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
    }
}

// MARK: - Edit Coupon Fields
struct EditCouponFields: View {
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
    }
}

// MARK: - Edit Store Card Fields
struct EditStoreCardFields: View {
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
    }
}

// MARK: - Edit Generic Fields
struct EditGenericFields: View {
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

// MARK: - Preview
#Preview {
    EditPassView(
        pass: SavedPass(
            from: PassTicket(
                ticketType: .eventTicket,
                organizationName: "Test Org",
                eventName: "Test Event"
            ),
            serialNumber: "TEST-001"
        ),
        storageManager: PassStorageManager()
    ) { _, _ in }
}
