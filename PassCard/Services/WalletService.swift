//
//  WalletService.swift
//  PassCard
//
//  Сервис для работы с Apple Wallet
//

import Foundation
import PassKit
import UIKit
import SwiftUI
import Combine

// MARK: - Wallet Error
enum WalletError: LocalizedError {
    case walletNotAvailable
    case passLibraryNotAvailable
    case invalidPassData
    case passAlreadyExists
    case addPassFailed(Error?)
    case cannotAddPass
    
    var errorDescription: String? {
        switch self {
        case .walletNotAvailable:
            return "Apple Wallet недоступен на этом устройстве"
        case .passLibraryNotAvailable:
            return "Библиотека пассов недоступна"
        case .invalidPassData:
            return "Недействительные данные пасса"
        case .passAlreadyExists:
            return "Этот пасс уже добавлен в Wallet"
        case .addPassFailed(let error):
            return "Не удалось добавить пасс: \(error?.localizedDescription ?? "неизвестная ошибка")"
        case .cannotAddPass:
            return "Невозможно добавить этот тип пасса"
        }
    }
}

// MARK: - Wallet Service
class WalletService: NSObject, ObservableObject {
    
    static let shared = WalletService()
    
    @Published var isWalletAvailable: Bool = false
    @Published var isAddingPass: Bool = false
    @Published var lastError: WalletError?
    
    private var passLibrary: PKPassLibrary?
    private var addPassCompletion: ((Result<Void, WalletError>) -> Void)?
    
    override init() {
        super.init()
        checkWalletAvailability()
    }
    
    // MARK: - Check Availability
    func checkWalletAvailability() {
        isWalletAvailable = PKPassLibrary.isPassLibraryAvailable()
        if isWalletAvailable {
            passLibrary = PKPassLibrary()
        }
    }
    
    // MARK: - Create PKPass from Data
    func createPass(from data: Data) throws -> PKPass {
        do {
            let pass = try PKPass(data: data)
            return pass
        } catch {
            throw WalletError.invalidPassData
        }
    }
    
    // MARK: - Check if Pass Exists
    func passExists(_ pass: PKPass) -> Bool {
        guard let library = passLibrary else { return false }
        return library.containsPass(pass)
    }
    
    func passExists(passTypeIdentifier: String, serialNumber: String) -> Bool {
        guard let library = passLibrary else { return false }
        return library.pass(withPassTypeIdentifier: passTypeIdentifier, serialNumber: serialNumber) != nil
    }
    
    // MARK: - Add Pass to Wallet (UIKit method)
    func addPassToWallet(data: Data, from viewController: UIViewController, completion: @escaping (Result<Void, WalletError>) -> Void) {
        guard isWalletAvailable else {
            completion(.failure(.walletNotAvailable))
            return
        }
        
        do {
            let pass = try createPass(from: data)
            
            // Проверяем, можно ли добавить пасс
            guard PKAddPassesViewController.canAddPasses() else {
                completion(.failure(.cannotAddPass))
                return
            }
            
            // Проверяем, не добавлен ли уже
            if passExists(pass) {
                completion(.failure(.passAlreadyExists))
                return
            }
            
            // Создаём контроллер добавления
            guard let addPassVC = PKAddPassesViewController(pass: pass) else {
                completion(.failure(.cannotAddPass))
                return
            }
            
            addPassVC.delegate = self
            self.addPassCompletion = completion
            self.isAddingPass = true
            
            DispatchQueue.main.async {
                viewController.present(addPassVC, animated: true)
            }
            
        } catch let error as WalletError {
            completion(.failure(error))
        } catch {
            completion(.failure(.addPassFailed(error)))
        }
    }
    
    // MARK: - Add Multiple Passes
    func addPassesToWallet(dataArray: [Data], from viewController: UIViewController, completion: @escaping (Result<Void, WalletError>) -> Void) {
        guard isWalletAvailable else {
            completion(.failure(.walletNotAvailable))
            return
        }
        
        do {
            let passes = try dataArray.map { try createPass(from: $0) }
            
            guard PKAddPassesViewController.canAddPasses() else {
                completion(.failure(.cannotAddPass))
                return
            }
            
            guard let addPassVC = PKAddPassesViewController(passes: passes) else {
                completion(.failure(.cannotAddPass))
                return
            }
            
            addPassVC.delegate = self
            self.addPassCompletion = completion
            self.isAddingPass = true
            
            DispatchQueue.main.async {
                viewController.present(addPassVC, animated: true)
            }
            
        } catch let error as WalletError {
            completion(.failure(error))
        } catch {
            completion(.failure(.addPassFailed(error)))
        }
    }
    
    // MARK: - Remove Pass
    func removePass(passTypeIdentifier: String, serialNumber: String) -> Bool {
        guard let library = passLibrary,
              let pass = library.pass(withPassTypeIdentifier: passTypeIdentifier, serialNumber: serialNumber) else {
            return false
        }
        
        library.removePass(pass)
        return true
    }
    
    // MARK: - Get All Passes
    func getAllPasses() -> [PKPass] {
        return passLibrary?.passes() ?? []
    }
    
    // MARK: - Save Pass to Files
    func savePassToFiles(data: Data, filename: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let passURL = documentsPath.appendingPathComponent("\(filename).pkpass")
        
        try data.write(to: passURL)
        return passURL
    }
    
    // MARK: - Share Pass
    func sharePass(data: Data, filename: String, from viewController: UIViewController) throws {
        let passURL = try savePassToFiles(data: data, filename: filename)
        
        let activityVC = UIActivityViewController(activityItems: [passURL], applicationActivities: nil)
        
        // Для iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        
        DispatchQueue.main.async {
            viewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - PKAddPassesViewControllerDelegate
extension WalletService: PKAddPassesViewControllerDelegate {
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        // Store completion before dismissing to ensure it's called only once
        let completion = addPassCompletion
        addPassCompletion = nil
        isAddingPass = false
        
        controller.dismiss(animated: true) {
            // Call completion after dismiss is complete
            completion?(.success(()))
        }
    }
}

// MARK: - SwiftUI Helper
struct WalletPassPresenter: UIViewControllerRepresentable {
    let passData: Data
    let onCompletion: (Result<Void, WalletError>) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WalletService.shared.addPassToWallet(data: passData, from: viewController, completion: onCompletion)
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
