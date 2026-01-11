//
//  QRCodeGenerator.swift
//  PassCard
//
//  Генератор QR-кодов и других штрих-кодов
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import SwiftUI

// MARK: - Barcode Generator
class BarcodeGenerator {
    
    static let shared = BarcodeGenerator()
    
    private let context = CIContext()
    
    // MARK: - Generate QR Code
    func generateQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        return generateImage(from: filter, size: size)
    }
    
    // MARK: - Generate PDF417
    func generatePDF417(from string: String, size: CGSize = CGSize(width: 300, height: 100)) -> UIImage? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        
        return generateImage(from: filter, size: size)
    }
    
    // MARK: - Generate Aztec
    func generateAztec(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let filter = CIFilter.aztecCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(33.0, forKey: "inputCorrectionLevel")
        
        return generateImage(from: filter, size: size)
    }
    
    // MARK: - Generate Code128
    func generateCode128(from string: String, size: CGSize = CGSize(width: 300, height: 80)) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        
        guard let data = string.data(using: .ascii) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        
        return generateImage(from: filter, size: size)
    }
    
    // MARK: - Generate by Format
    func generateBarcode(from string: String, format: BarcodeFormat, size: CGSize? = nil) -> UIImage? {
        switch format {
        case .qr:
            return generateQRCode(from: string, size: size ?? CGSize(width: 200, height: 200))
        case .pdf417:
            return generatePDF417(from: string, size: size ?? CGSize(width: 300, height: 100))
        case .aztec:
            return generateAztec(from: string, size: size ?? CGSize(width: 200, height: 200))
        case .code128:
            return generateCode128(from: string, size: size ?? CGSize(width: 300, height: 80))
        }
    }
    
    // MARK: - Private Helper
    private func generateImage(from filter: CIFilter, size: CGSize) -> UIImage? {
        guard let outputImage = filter.outputImage else { return nil }
        
        // Масштабируем до нужного размера
        let scaleX = size.width / outputImage.extent.size.width
        let scaleY = size.height / outputImage.extent.size.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - SwiftUI View for Barcode
struct BarcodeView: View {
    let content: String
    let format: BarcodeFormat
    let foregroundColor: Color
    let backgroundColor: Color
    
    init(
        content: String,
        format: BarcodeFormat = .qr,
        foregroundColor: Color = .black,
        backgroundColor: Color = .white
    ) {
        self.content = content
        self.format = format
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        if let image = BarcodeGenerator.shared.generateBarcode(from: content, format: format) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .colorMultiply(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(8)
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text("Не удалось создать код")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        BarcodeView(content: "https://example.com/ticket/12345", format: .qr)
            .frame(width: 150, height: 150)
        
        BarcodeView(content: "TICKET-12345-ABCDE", format: .pdf417)
            .frame(width: 250, height: 80)
        
        BarcodeView(content: "123456789", format: .code128)
            .frame(width: 200, height: 60)
    }
    .padding()
}
