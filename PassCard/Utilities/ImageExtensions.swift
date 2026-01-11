//
//  ImageExtensions.swift
//  PassCard
//
//  Расширения для работы с изображениями
//

import SwiftUI
import UIKit

// MARK: - UIImage Extensions
extension UIImage {
    
    // Изменение размера изображения
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // Конвертация в PNG Data
    var pngData: Data? {
        return self.pngData()
    }
    
    // Конвертация в Base64
    func toBase64() -> String? {
        guard let data = self.pngData() else { return nil }
        return data.base64EncodedString()
    }
    
    // Создание из Base64
    static func fromBase64(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
    
    // Создание квадратного изображения с обрезкой
    func squareCropped() -> UIImage? {
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        
        guard let cgImage = self.cgImage?.cropping(to: CGRect(x: x, y: y, width: side, height: side)) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    // Создание иконки для пасса (размеры Apple: icon.png = 29x29, icon@2x.png = 58x58, icon@3x.png = 87x87)
    func passIcon() -> UIImage? {
        return self.squareCropped()?.resized(to: CGSize(width: 87, height: 87))
    }
    
    // Создание логотипа для пасса (logo.png = 160x50 @1x, рекомендуется @2x = 320x100)
    func passLogo() -> UIImage? {
        let targetSize = CGSize(width: 320, height: 100)
        let ratio = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return self.resized(to: newSize)
    }
    
    // Создание фона для пасса (background.png = 180x220 @1x, @2x = 360x440)
    func passBackground() -> UIImage? {
        return self.resized(to: CGSize(width: 360, height: 440))
    }
    
    // Создание миниатюры для пасса (thumbnail.png = 90x90 @1x, @2x = 180x180)
    func passThumbnail() -> UIImage? {
        return self.squareCropped()?.resized(to: CGSize(width: 180, height: 180))
    }
    
    // Создание полоски для пасса (strip.png = 320x84 @1x, @2x = 640x168)
    func passStrip() -> UIImage? {
        return self.resized(to: CGSize(width: 640, height: 168))
    }
}

// MARK: - Data Extensions
extension Data {
    // SHA1 хеш для manifest.json
    var sha1Hash: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = self.withUnsafeBytes {
            CC_SHA1($0.baseAddress, CC_LONG(self.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Для использования CC_SHA1
import CommonCrypto

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Selection Button
struct ImageSelectionButton: View {
    let title: String
    let subtitle: String
    @Binding var selectedImage: UIImage?
    @State private var showingPicker = false
    
    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedImage != nil {
                    Button {
                        selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ImageSelectionButton(
            title: "Логотип",
            subtitle: "320x100 px рекомендуется",
            selectedImage: .constant(nil)
        )
        
        ImageSelectionButton(
            title: "Иконка",
            subtitle: "87x87 px",
            selectedImage: .constant(UIImage(systemName: "star.fill"))
        )
    }
    .padding()
}
