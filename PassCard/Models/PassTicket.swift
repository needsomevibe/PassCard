//
//  PassTicket.swift
//  PassCard
//
//  Модель билета для создания Wallet Pass
//

import Foundation
import SwiftUI
import Combine

// MARK: - Pass Ticket Model
struct PassTicket: Identifiable, Codable {
    let id: UUID
    var ticketType: TicketType
    
    // Общие поля
    var organizationName: String
    var description: String
    var logoText: String?
    
    // Цвета
    var backgroundColor: String
    var foregroundColor: String
    var labelColor: String
    
    // Штрих-код
    var barcodeMessage: String
    var barcodeFormat: BarcodeFormat
    
    // Event Ticket Fields
    var eventName: String
    var eventDate: Date
    var eventTime: Date
    var venueName: String
    var venueAddress: String
    var seatSection: String?
    var seatRow: String?
    var seatNumber: String?
    var ticketHolder: String?
    var ticketCategory: String?
    
    // Boarding Pass Fields
    var passengerName: String?
    var flightNumber: String?
    var originCode: String?
    var originCity: String?
    var destinationCode: String?
    var destinationCity: String?
    var departureTime: Date?
    var arrivalTime: Date?
    var gate: String?
    var boardingGroup: String?
    var seatClass: String?
    var confirmationCode: String?
    
    // Coupon Fields
    var couponTitle: String?
    var discountAmount: String?
    var promoCode: String?
    var expirationDate: Date?
    var termsAndConditions: String?
    var storeName: String?
    
    // Store Card Fields
    var cardholderName: String?
    var membershipLevel: String?
    var pointsBalance: String?
    var memberSince: Date?
    
    // Generic Fields
    var primaryLabel: String?
    var primaryValue: String?
    var secondaryLabel: String?
    var secondaryValue: String?
    
    init(
        id: UUID = UUID(),
        ticketType: TicketType = .eventTicket,
        organizationName: String = "",
        description: String = "",
        logoText: String? = nil,
        backgroundColor: String = "#1C1C1E",
        foregroundColor: String = "#FFFFFF",
        labelColor: String = "#8E8E93",
        barcodeMessage: String = "",
        barcodeFormat: BarcodeFormat = .qr,
        eventName: String = "",
        eventDate: Date = Date(),
        eventTime: Date = Date(),
        venueName: String = "",
        venueAddress: String = "",
        seatSection: String? = nil,
        seatRow: String? = nil,
        seatNumber: String? = nil,
        ticketHolder: String? = nil,
        ticketCategory: String? = nil,
        passengerName: String? = nil,
        flightNumber: String? = nil,
        originCode: String? = nil,
        originCity: String? = nil,
        destinationCode: String? = nil,
        destinationCity: String? = nil,
        departureTime: Date? = nil,
        arrivalTime: Date? = nil,
        gate: String? = nil,
        boardingGroup: String? = nil,
        seatClass: String? = nil,
        confirmationCode: String? = nil,
        couponTitle: String? = nil,
        discountAmount: String? = nil,
        promoCode: String? = nil,
        expirationDate: Date? = nil,
        termsAndConditions: String? = nil,
        storeName: String? = nil,
        cardholderName: String? = nil,
        membershipLevel: String? = nil,
        pointsBalance: String? = nil,
        memberSince: Date? = nil,
        primaryLabel: String? = nil,
        primaryValue: String? = nil,
        secondaryLabel: String? = nil,
        secondaryValue: String? = nil
    ) {
        self.id = id
        self.ticketType = ticketType
        self.organizationName = organizationName
        self.description = description
        self.logoText = logoText
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.labelColor = labelColor
        self.barcodeMessage = barcodeMessage.isEmpty ? id.uuidString : barcodeMessage
        self.barcodeFormat = barcodeFormat
        self.eventName = eventName
        self.eventDate = eventDate
        self.eventTime = eventTime
        self.venueName = venueName
        self.venueAddress = venueAddress
        self.seatSection = seatSection
        self.seatRow = seatRow
        self.seatNumber = seatNumber
        self.ticketHolder = ticketHolder
        self.ticketCategory = ticketCategory
        self.passengerName = passengerName
        self.flightNumber = flightNumber
        self.originCode = originCode
        self.originCity = originCity
        self.destinationCode = destinationCode
        self.destinationCity = destinationCity
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.gate = gate
        self.boardingGroup = boardingGroup
        self.seatClass = seatClass
        self.confirmationCode = confirmationCode
        self.couponTitle = couponTitle
        self.discountAmount = discountAmount
        self.promoCode = promoCode
        self.expirationDate = expirationDate
        self.termsAndConditions = termsAndConditions
        self.storeName = storeName
        self.cardholderName = cardholderName
        self.membershipLevel = membershipLevel
        self.pointsBalance = pointsBalance
        self.memberSince = memberSince
        self.primaryLabel = primaryLabel
        self.primaryValue = primaryValue
        self.secondaryLabel = secondaryLabel
        self.secondaryValue = secondaryValue
    }
    
    // Initialize from SavedPass for editing
    init(from savedPass: SavedPass) {
        self.id = savedPass.id
        self.ticketType = savedPass.ticketType
        self.organizationName = savedPass.organizationName
        self.description = ""
        self.logoText = nil
        self.backgroundColor = savedPass.backgroundColor
        self.foregroundColor = savedPass.foregroundColor
        self.labelColor = savedPass.labelColor
        self.barcodeMessage = savedPass.barcodeMessage
        self.barcodeFormat = savedPass.barcodeFormat
        self.eventName = savedPass.eventName
        self.eventDate = savedPass.eventDate
        self.eventTime = savedPass.eventTime
        self.venueName = savedPass.venueName
        self.venueAddress = savedPass.venueAddress
        self.seatSection = savedPass.seatSection
        self.seatRow = savedPass.seatRow
        self.seatNumber = savedPass.seatNumber
        self.ticketHolder = savedPass.ticketHolder
        self.ticketCategory = nil
        self.passengerName = savedPass.passengerName
        self.flightNumber = savedPass.flightNumber
        self.originCode = savedPass.originCode
        self.originCity = nil
        self.destinationCode = savedPass.destinationCode
        self.destinationCity = nil
        self.departureTime = nil
        self.arrivalTime = nil
        self.gate = savedPass.gate
        self.boardingGroup = nil
        self.seatClass = savedPass.seatClass
        self.confirmationCode = savedPass.confirmationCode
        self.couponTitle = savedPass.couponTitle
        self.discountAmount = savedPass.discountAmount
        self.promoCode = savedPass.promoCode
        self.expirationDate = savedPass.expirationDate
        self.termsAndConditions = nil
        self.storeName = savedPass.storeName
        self.cardholderName = savedPass.cardholderName
        self.membershipLevel = savedPass.membershipLevel
        self.pointsBalance = savedPass.pointsBalance
        self.memberSince = nil
        self.primaryLabel = savedPass.primaryLabel
        self.primaryValue = savedPass.primaryValue
        self.secondaryLabel = savedPass.secondaryLabel
        self.secondaryValue = savedPass.secondaryValue
    }
    
    // Форматированная дата
    var formattedDate: String {
        eventDate.formatted(date: .long, time: .omitted)
    }
    
    var formattedTime: String {
        eventTime.formatted(date: .omitted, time: .shortened)
    }
    
    var isoDate: String {
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: eventTime)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.timeZone = TimeZone.current
        
        if let date = calendar.date(from: combined) {
            return formatter.string(from: date)
        }
        return formatter.string(from: eventDate)
    }
    
    // Получить название для отображения
    var displayName: String {
        switch ticketType {
        case .eventTicket:
            return eventName.isEmpty ? String(localized: "new_event") : eventName
        case .boardingPass:
            if let origin = originCode, let dest = destinationCode, !origin.isEmpty, !dest.isEmpty {
                return "\(origin) → \(dest)"
            }
            return flightNumber ?? String(localized: "new_flight")
        case .coupon:
            return couponTitle ?? String(localized: "new_coupon")
        case .storeCard:
            return organizationName.isEmpty ? String(localized: "new_card") : organizationName
        case .generic:
            return primaryValue ?? String(localized: "new_pass")
        }
    }
    
    // Сформировать место (для eventTicket)
    var seatInfo: String? {
        var parts: [String] = []
        if let section = seatSection, !section.isEmpty {
            parts.append(String(localized: "section_short") + " \(section)")
        }
        if let row = seatRow, !row.isEmpty {
            parts.append(String(localized: "row_short") + " \(row)")
        }
        if let seat = seatNumber, !seat.isEmpty {
            parts.append(String(localized: "seat_short") + " \(seat)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Ticket Type
enum TicketType: String, Codable, CaseIterable, Identifiable {
    case eventTicket = "eventTicket"
    case boardingPass = "boardingPass"
    case coupon = "coupon"
    case storeCard = "storeCard"
    case generic = "generic"
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .eventTicket: return "pass_type_event"
        case .boardingPass: return "pass_type_boarding"
        case .coupon: return "pass_type_coupon"
        case .storeCard: return "pass_type_store"
        case .generic: return "pass_type_generic"
        }
    }
    
    var icon: String {
        switch self {
        case .eventTicket: return "ticket.fill"
        case .boardingPass: return "airplane"
        case .coupon: return "tag.fill"
        case .storeCard: return "creditcard.fill"
        case .generic: return "rectangle.on.rectangle.fill"
        }
    }
    
    var description: LocalizedStringKey {
        switch self {
        case .eventTicket: return "pass_type_event_desc"
        case .boardingPass: return "pass_type_boarding_desc"
        case .coupon: return "pass_type_coupon_desc"
        case .storeCard: return "pass_type_store_desc"
        case .generic: return "pass_type_generic_desc"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .eventTicket: return .purple
        case .boardingPass: return .blue
        case .coupon: return .orange
        case .storeCard: return .green
        case .generic: return .gray
        }
    }
}

// MARK: - Barcode Format
enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
    case qr = "PKBarcodeFormatQR"
    case pdf417 = "PKBarcodeFormatPDF417"
    case aztec = "PKBarcodeFormatAztec"
    case code128 = "PKBarcodeFormatCode128"
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .qr: return "barcode_qr"
        case .pdf417: return "barcode_pdf417"
        case .aztec: return "barcode_aztec"
        case .code128: return "barcode_code128"
        }
    }
    
    var icon: String {
        switch self {
        case .qr: return "qrcode"
        case .pdf417: return "barcode"
        case .aztec: return "viewfinder"
        case .code128: return "barcode.viewfinder"
        }
    }
}

// MARK: - Pass Request
struct CreatePassRequest: Codable {
    let ticket: PassTicket
    let deviceId: String
    let logoImageBase64: String?
    let iconImageBase64: String?
    let backgroundImageBase64: String?
    let thumbnailImageBase64: String?
    let stripImageBase64: String?
    
    init(
        ticket: PassTicket,
        deviceId: String = UUID().uuidString,
        logoImageBase64: String? = nil,
        iconImageBase64: String? = nil,
        backgroundImageBase64: String? = nil,
        thumbnailImageBase64: String? = nil,
        stripImageBase64: String? = nil
    ) {
        self.ticket = ticket
        self.deviceId = deviceId
        self.logoImageBase64 = logoImageBase64
        self.iconImageBase64 = iconImageBase64
        self.backgroundImageBase64 = backgroundImageBase64
        self.thumbnailImageBase64 = thumbnailImageBase64
        self.stripImageBase64 = stripImageBase64
    }
}

// MARK: - Pass Response
struct PassResponse: Codable {
    let success: Bool
    let passData: Data?
    let serialNumber: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case passData = "pass_data"
        case serialNumber = "serial_number"
        case error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        
        if let base64String = try container.decodeIfPresent(String.self, forKey: .passData) {
            passData = Data(base64Encoded: base64String)
        } else {
            passData = nil
        }
    }
}

// MARK: - Color Presets
struct PassColorPreset: Identifiable {
    let id = UUID()
    let name: LocalizedStringKey
    let backgroundColor: String
    let foregroundColor: String
    let labelColor: String
    
    static let presets: [PassColorPreset] = [
        PassColorPreset(name: "color_midnight", backgroundColor: "#1C1C1E", foregroundColor: "#FFFFFF", labelColor: "#8E8E93"),
        PassColorPreset(name: "color_ocean", backgroundColor: "#007AFF", foregroundColor: "#FFFFFF", labelColor: "#E5F1FF"),
        PassColorPreset(name: "color_forest", backgroundColor: "#34C759", foregroundColor: "#FFFFFF", labelColor: "#E3F9E8"),
        PassColorPreset(name: "color_sunset", backgroundColor: "#FF9500", foregroundColor: "#FFFFFF", labelColor: "#FFF3E0"),
        PassColorPreset(name: "color_berry", backgroundColor: "#AF52DE", foregroundColor: "#FFFFFF", labelColor: "#F3E8FA"),
        PassColorPreset(name: "color_coral", backgroundColor: "#FF3B30", foregroundColor: "#FFFFFF", labelColor: "#FFE5E3"),
        PassColorPreset(name: "color_teal", backgroundColor: "#5AC8FA", foregroundColor: "#000000", labelColor: "#1C1C1E"),
        PassColorPreset(name: "color_indigo", backgroundColor: "#5856D6", foregroundColor: "#FFFFFF", labelColor: "#EEEEFF"),
        PassColorPreset(name: "color_pink", backgroundColor: "#FF2D55", foregroundColor: "#FFFFFF", labelColor: "#FFE5EB"),
        PassColorPreset(name: "color_graphite", backgroundColor: "#48484A", foregroundColor: "#FFFFFF", labelColor: "#AEAEB2"),
    ]
}
