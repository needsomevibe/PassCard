//
//  PassAPIService.swift
//  PassCard
//
//  Сервис для взаимодействия с сервером генерации пассов
//

import Foundation
import Combine

// MARK: - API Error
enum PassAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case noPassData
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL сервера"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Ошибка обработки ответа: \(error.localizedDescription)"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        case .noPassData:
            return "Сервер не вернул данные пасса"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        }
    }
}

// MARK: - API Service Protocol
protocol PassAPIServiceProtocol {
    func createPass(request: CreatePassRequest) async throws -> (Data, String)
    func getPass(serialNumber: String) async throws -> Data
    func deletePass(serialNumber: String) async throws
}

// MARK: - Pass API Service
class PassAPIService: PassAPIServiceProtocol, ObservableObject {
    
    // ВАЖНО: Замените на ваш реальный URL сервера
    // Для локальной разработки используйте ngrok или локальный IP
    static let shared = PassAPIService()
    
    private var baseURL: String {
        // Для симулятора можно использовать localhost
        // Для реального устройства нужен ngrok или публичный сервер
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:3000"
        #else
        // Render server URL
        return UserDefaults.standard.string(forKey: "serverURL") ?? "https://passcard-1.onrender.com"
        #endif
    }
    
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Set Server URL
    func setServerURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "serverURL")
    }
    
    func getServerURL() -> String {
        return baseURL
    }
    
    // MARK: - Create Pass
    func createPass(request: CreatePassRequest) async throws -> (Data, String) {
        guard let url = URL(string: "\(baseURL)/api/passes/create") else {
            throw PassAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PassAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                // Если ответ - application/vnd.apple.pkpass, возвращаем сырые данные
                if httpResponse.mimeType == "application/vnd.apple.pkpass" {
                    let serialNumber = httpResponse.value(forHTTPHeaderField: "X-Serial-Number") ?? request.ticket.id.uuidString
                    return (data, serialNumber)
                }
                
                // Иначе парсим JSON
                let decoder = JSONDecoder()
                let passResponse = try decoder.decode(PassResponse.self, from: data)
                
                if passResponse.success, let passData = passResponse.passData {
                    return (passData, passResponse.serialNumber ?? request.ticket.id.uuidString)
                } else {
                    throw PassAPIError.serverError(passResponse.error ?? "Неизвестная ошибка")
                }
            } else {
                // Пытаемся получить сообщение об ошибке
                if let errorResponse = try? JSONDecoder().decode(PassResponse.self, from: data) {
                    throw PassAPIError.serverError(errorResponse.error ?? "HTTP \(httpResponse.statusCode)")
                }
                throw PassAPIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as PassAPIError {
            throw error
        } catch let error as DecodingError {
            throw PassAPIError.decodingError(error)
        } catch {
            throw PassAPIError.networkError(error)
        }
    }
    
    // MARK: - Get Existing Pass
    func getPass(serialNumber: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/passes/\(serialNumber)") else {
            throw PassAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw PassAPIError.invalidResponse
            }
            
            return data
        } catch let error as PassAPIError {
            throw error
        } catch {
            throw PassAPIError.networkError(error)
        }
    }
    
    // MARK: - Update Pass
    func updatePass(serialNumber: String, request: CreatePassRequest) async throws -> (Data, String) {
        guard let url = URL(string: "\(baseURL)/api/passes/\(serialNumber)") else {
            throw PassAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PassAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                if httpResponse.mimeType == "application/vnd.apple.pkpass" {
                    let newSerialNumber = httpResponse.value(forHTTPHeaderField: "X-Serial-Number") ?? serialNumber
                    return (data, newSerialNumber)
                }
                
                let decoder = JSONDecoder()
                let passResponse = try decoder.decode(PassResponse.self, from: data)
                
                if passResponse.success, let passData = passResponse.passData {
                    return (passData, passResponse.serialNumber ?? serialNumber)
                } else {
                    throw PassAPIError.serverError(passResponse.error ?? "Unknown error")
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(PassResponse.self, from: data) {
                    throw PassAPIError.serverError(errorResponse.error ?? "HTTP \(httpResponse.statusCode)")
                }
                throw PassAPIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as PassAPIError {
            throw error
        } catch let error as DecodingError {
            throw PassAPIError.decodingError(error)
        } catch {
            throw PassAPIError.networkError(error)
        }
    }
    
    // MARK: - Delete Pass
    func deletePass(serialNumber: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/passes/\(serialNumber)") else {
            throw PassAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw PassAPIError.invalidResponse
            }
        } catch let error as PassAPIError {
            throw error
        } catch {
            throw PassAPIError.networkError(error)
        }
    }
    
    // MARK: - Health Check
    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Mock Service for Preview
class MockPassAPIService: PassAPIServiceProtocol {
    func createPass(request: CreatePassRequest) async throws -> (Data, String) {
        // Симулируем задержку сети
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Возвращаем пустые данные для превью
        return (Data(), request.ticket.id.uuidString)
    }
    
    func getPass(serialNumber: String) async throws -> Data {
        return Data()
    }
    
    func deletePass(serialNumber: String) async throws {
        // No-op
    }
}
