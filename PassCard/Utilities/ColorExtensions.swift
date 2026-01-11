//
//  ColorExtensions.swift
//  PassCard
//
//  Расширения для работы с цветами
//

import SwiftUI
import UIKit

// MARK: - Color Extensions
extension Color {
    
    // Инициализация из HEX строки
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Конвертация в HEX строку
    func toHex(includeAlpha: Bool = false) -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let r = Int((components[0] * 255).rounded())
        let g = Int(((components.count > 1 ? components[1] : components[0]) * 255).rounded())
        let b = Int(((components.count > 2 ? components[2] : components[0]) * 255).rounded())
        
        if includeAlpha, components.count > 3 {
            let a = Int((components[3] * 255).rounded())
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // RGB компоненты для pass.json
    func toRGBString() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "rgb(0, 0, 0)"
        }
        
        let r = Int((components[0] * 255).rounded())
        let g = Int(((components.count > 1 ? components[1] : components[0]) * 255).rounded())
        let b = Int(((components.count > 2 ? components[2] : components[0]) * 255).rounded())
        
        return "rgb(\(r), \(g), \(b))"
    }
    
    // Определение, светлый или тёмный цвет
    var isLight: Bool {
        guard let components = UIColor(self).cgColor.components else { return false }
        
        let r = components[0]
        let g = components.count > 1 ? components[1] : components[0]
        let b = components.count > 2 ? components[2] : components[0]
        
        // Формула YIQ для определения яркости
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        return brightness > 0.5
    }
    
    // Контрастный цвет (для текста)
    var contrastColor: Color {
        isLight ? .black : .white
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Color Picker Wrapper
struct HexColorPicker: View {
    @Binding var hexColor: String
    @State private var color: Color
    
    init(hexColor: Binding<String>) {
        self._hexColor = hexColor
        self._color = State(initialValue: Color(hex: hexColor.wrappedValue))
    }
    
    var body: some View {
        HStack {
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color) { _, newValue in
                    hexColor = newValue.toHex()
                }
            
            TextField("HEX", text: $hexColor)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.allCharacters)
                .onChange(of: hexColor) { _, newValue in
                    color = Color(hex: newValue)
                }
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: hexColor))
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HexColorPicker(hexColor: .constant("#FF6B35"))
        
        HStack {
            ForEach(PassColorPreset.presets.prefix(5)) { preset in
                Circle()
                    .fill(Color(hex: preset.backgroundColor))
                    .frame(width: 40, height: 40)
            }
        }
    }
    .padding()
}
