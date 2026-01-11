//
//  SavedPass.swift
//  PassCard
//
//  Model for saved pass (local storage)
//

import Foundation
import SwiftUI
import Combine

struct SavedPass: Identifiable, Codable, Equatable {
    let id: UUID
    var serialNumber: String
    var eventName: String
    var eventDate: Date
    var eventTime: Date
    var venueName: String
    var venueAddress: String
    var organizationName: String
    var createdAt: Date
    var ticketType: TicketType
    var backgroundColor: String
    var foregroundColor: String
    var labelColor: String
    var barcodeMessage: String
    var barcodeFormat: BarcodeFormat
    var isAddedToWallet: Bool
    
    // Optional fields for different pass types
    var seatSection: String?
    var seatRow: String?
    var seatNumber: String?
    var ticketHolder: String?
    
    // Boarding pass
    var passengerName: String?
    var flightNumber: String?
    var originCode: String?
    var destinationCode: String?
    var gate: String?
    var seatClass: String?
    var confirmationCode: String?
    
    // Coupon
    var couponTitle: String?
    var discountAmount: String?
    var promoCode: String?
    var expirationDate: Date?
    var storeName: String?
    
    // Store card
    var cardholderName: String?
    var membershipLevel: String?
    var pointsBalance: String?
    
    // Generic
    var primaryLabel: String?
    var primaryValue: String?
    var secondaryLabel: String?
    var secondaryValue: String?
    
    init(from ticket: PassTicket, serialNumber: String) {
        self.id = ticket.id
        self.serialNumber = serialNumber
        self.eventName = ticket.displayName
        self.eventDate = ticket.eventDate
        self.eventTime = ticket.eventTime
        self.venueName = ticket.venueName
        self.venueAddress = ticket.venueAddress
        self.organizationName = ticket.organizationName
        self.createdAt = Date()
        self.ticketType = ticket.ticketType
        self.backgroundColor = ticket.backgroundColor
        self.foregroundColor = ticket.foregroundColor
        self.labelColor = ticket.labelColor
        self.barcodeMessage = ticket.barcodeMessage
        self.barcodeFormat = ticket.barcodeFormat
        self.isAddedToWallet = false
        
        // Event ticket
        self.seatSection = ticket.seatSection
        self.seatRow = ticket.seatRow
        self.seatNumber = ticket.seatNumber
        self.ticketHolder = ticket.ticketHolder
        
        // Boarding pass
        self.passengerName = ticket.passengerName
        self.flightNumber = ticket.flightNumber
        self.originCode = ticket.originCode
        self.destinationCode = ticket.destinationCode
        self.gate = ticket.gate
        self.seatClass = ticket.seatClass
        self.confirmationCode = ticket.confirmationCode
        
        // Coupon
        self.couponTitle = ticket.couponTitle
        self.discountAmount = ticket.discountAmount
        self.promoCode = ticket.promoCode
        self.expirationDate = ticket.expirationDate
        self.storeName = ticket.storeName
        
        // Store card
        self.cardholderName = ticket.cardholderName
        self.membershipLevel = ticket.membershipLevel
        self.pointsBalance = ticket.pointsBalance
        
        // Generic
        self.primaryLabel = ticket.primaryLabel
        self.primaryValue = ticket.primaryValue
        self.secondaryLabel = ticket.secondaryLabel
        self.secondaryValue = ticket.secondaryValue
    }
    
    var formattedDate: String {
        eventDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    var formattedCreatedAt: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Pass Storage Manager with iCloud Sync
class PassStorageManager: ObservableObject {
    @Published var savedPasses: [SavedPass] = []
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let localStorageKey = "savedPasses_v2"
    private let iCloudStorageKey = "iCloud_savedPasses_v2"
    private let lastSyncKey = "lastSyncDate"
    
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = true
    
    init() {
        loadPasses()
        setupiCloudObserver()
        
        // Initial sync if premium
        if iCloudSyncEnabled && isPremium {
            syncFromiCloud()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - iCloud Observer
    private func setupiCloudObserver() {
        guard isPremium else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        
        // Synchronize to get latest data
        iCloudStore.synchronize()
    }
    
    @objc private func iCloudDidChangeExternally(_ notification: Notification) {
        guard iCloudSyncEnabled && isPremium else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.syncFromiCloud()
        }
    }
    
    // MARK: - Public Methods
    func savePass(_ pass: SavedPass) {
        savedPasses.insert(pass, at: 0)
        persistPasses()
    }
    
    func updatePass(_ pass: SavedPass) {
        if let index = savedPasses.firstIndex(where: { $0.id == pass.id }) {
            savedPasses[index] = pass
            persistPasses()
        }
    }
    
    func deletePass(_ pass: SavedPass) {
        savedPasses.removeAll { $0.id == pass.id }
        persistPasses()
    }
    
    func deletePass(at offsets: IndexSet) {
        savedPasses.remove(atOffsets: offsets)
        persistPasses()
    }
    
    func clearAll() {
        savedPasses.removeAll()
        persistPasses()
    }
    
    func forceSync() {
        guard iCloudSyncEnabled && isPremium else { return }
        
        isSyncing = true
        
        // Push to iCloud
        persistToiCloud()
        
        // Pull from iCloud
        iCloudStore.synchronize()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.syncFromiCloud()
            self?.isSyncing = false
        }
    }
    
    // MARK: - Private Methods
    private func loadPasses() {
        // Load from local storage first
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let passes = try? JSONDecoder().decode([SavedPass].self, from: data) {
            savedPasses = passes
        }
        
        // Load last sync date
        if let syncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = syncDate
        }
    }
    
    func persistPasses() {
        // Save locally
        if let data = try? JSONEncoder().encode(savedPasses) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
        
        // Save to iCloud if enabled and premium
        if iCloudSyncEnabled && isPremium {
            persistToiCloud()
        }
    }
    
    private var isPremium: Bool {
        UserDefaults.standard.bool(forKey: "isPremium")
    }
    
    private func persistToiCloud() {
        if let data = try? JSONEncoder().encode(savedPasses) {
            iCloudStore.set(data, forKey: iCloudStorageKey)
            iCloudStore.synchronize()
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        }
    }
    
    private func syncFromiCloud() {
        guard let data = iCloudStore.data(forKey: iCloudStorageKey),
              let iCloudPasses = try? JSONDecoder().decode([SavedPass].self, from: data) else {
            return
        }
        
        // Merge strategy: Keep all unique passes, prefer newer versions
        var mergedPasses = [UUID: SavedPass]()
        
        // Add local passes
        for pass in savedPasses {
            mergedPasses[pass.id] = pass
        }
        
        // Merge iCloud passes (prefer iCloud if same ID)
        for pass in iCloudPasses {
            if let existing = mergedPasses[pass.id] {
                // Keep the one with later createdAt
                if pass.createdAt > existing.createdAt {
                    mergedPasses[pass.id] = pass
                }
            } else {
                mergedPasses[pass.id] = pass
            }
        }
        
        // Sort by creation date (newest first)
        let sorted = mergedPasses.values.sorted { $0.createdAt > $1.createdAt }
        
        if sorted != savedPasses {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.savedPasses = sorted
                self.lastSyncDate = Date()
                
                // Save merged result locally
                if let data = try? JSONEncoder().encode(sorted) {
                    UserDefaults.standard.set(data, forKey: self.localStorageKey)
                }
            }
        }
    }
}
