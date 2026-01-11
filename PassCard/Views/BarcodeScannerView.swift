//
//  BarcodeScannerView.swift
//  PassCard
//
//  Camera scanner for QR codes and barcodes
//

import SwiftUI
import AVFoundation
import Vision

struct BarcodeScannerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var scannedCode: String
    
    @State private var isScanning = true
    @State private var detectedCode: String?
    @State private var showingImagePicker = false
    @State private var flashOn = false
    @State private var animatePulse = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera view
                CameraPreview(
                    isScanning: $isScanning,
                    detectedCode: $detectedCode,
                    flashOn: $flashOn
                )
                .ignoresSafeArea()
                
                // Overlay
                VStack {
                    Spacer()
                    
                    // Scan frame
                    ZStack {
                        // Corner brackets
                        ScannerFrame()
                            .stroke(detectedCode != nil ? Color.green : Color.white, lineWidth: 3)
                            .frame(width: 280, height: 280)
                        
                        // Animated scan line
                        if isScanning && detectedCode == nil {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.8), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 260, height: 2)
                                .offset(y: animatePulse ? 120 : -120)
                                .animation(
                                    .easeInOut(duration: 2)
                                    .repeatForever(autoreverses: true),
                                    value: animatePulse
                                )
                        }
                        
                        // Success checkmark
                        if detectedCode != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        if let code = detectedCode {
                            // Detected code display
                            VStack(spacing: 8) {
                                Text("code_detected")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            
                            Button {
                                HapticManager.shared.success()
                                scannedCode = code
                                dismiss()
                            } label: {
                                Text("use_this_code")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.horizontal, 40)
                            
                            Button {
                                HapticManager.shared.lightImpact()
                                withAnimation {
                                    detectedCode = nil
                                }
                            } label: {
                                Text("scan_again")
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Text("point_camera_at_code")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding()
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                animatePulse = true
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("scan_code")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Flash toggle
                        Button {
                            HapticManager.shared.lightImpact()
                            flashOn.toggle()
                        } label: {
                            Image(systemName: flashOn ? "bolt.fill" : "bolt.slash")
                                .font(.title3)
                                .foregroundStyle(flashOn ? .yellow : .white.opacity(0.8))
                        }
                        
                        // Photo library
                        Button {
                            HapticManager.shared.lightImpact()
                            showingImagePicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingImagePicker) {
                ImageCodePicker(scannedCode: $detectedCode)
            }
        }
    }
}

// MARK: - Scanner Frame Shape
struct ScannerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 30
        
        // Top left
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        // Top right
        path.move(to: CGPoint(x: rect.width - cornerLength, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: cornerLength))
        
        // Bottom right
        path.move(to: CGPoint(x: rect.width, y: rect.height - cornerLength))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - cornerLength, y: rect.height))
        
        // Bottom left
        path.move(to: CGPoint(x: cornerLength, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - cornerLength))
        
        return path
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var detectedCode: String?
    @Binding var flashOn: Bool
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setFlash(flashOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        func didDetectCode(_ code: String) {
            DispatchQueue.main.async {
                if self.parent.detectedCode == nil {
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.3)) {
                        self.parent.detectedCode = code
                    }
                }
            }
        }
    }
}

protocol CameraPreviewDelegate: AnyObject {
    func didDetectCode(_ code: String)
}

class CameraPreviewView: UIView {
    weak var delegate: CameraPreviewDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [
                .qr, .ean8, .ean13, .pdf417, .aztec, .code128, .code39, .code93, .upce
            ]
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        
        captureSession = session
        previewLayer = preview
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func setFlash(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    deinit {
        captureSession?.stopRunning()
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }
}

extension CameraPreviewView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        
        delegate?.didDetectCode(code)
    }
}

// MARK: - Image Code Picker
struct ImageCodePicker: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCodePicker
        
        init(_ parent: ImageCodePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.originalImage] as? UIImage,
                  let cgImage = image.cgImage else {
                picker.dismiss(animated: true)
                return
            }
            
            // Use Vision to detect barcodes
            let request = VNDetectBarcodesRequest { request, error in
                guard let results = request.results as? [VNBarcodeObservation],
                      let code = results.first?.payloadStringValue else {
                    DispatchQueue.main.async {
                        HapticManager.shared.error()
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    HapticManager.shared.success()
                    self.parent.scannedCode = code
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview
#Preview {
    BarcodeScannerView(scannedCode: .constant(""))
}
