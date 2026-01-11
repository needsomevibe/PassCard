//
//  HapticManager.swift
//  PassCard
//
//  Haptic feedback manager
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }
    
    private init() {
        // Set default value if not set
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "hapticsEnabled")
        }
    }
    
    // MARK: - Impact
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func lightImpact() {
        impact(.light)
    }
    
    func mediumImpact() {
        impact(.medium)
    }
    
    func heavyImpact() {
        impact(.heavy)
    }
    
    func softImpact() {
        impact(.soft)
    }
    
    func rigidImpact() {
        impact(.rigid)
    }
    
    // MARK: - Selection
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Notification
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func success() {
        notification(.success)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func error() {
        notification(.error)
    }
}
