//
//  GLMChatService.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import Foundation

// MARK: - AI Model Output Limits  
private func getMaxOutputTokens(for model: AIModel) -> Int {
    switch model {
    case .glm4Flash:
        return 4095
    case .gemini2Flash:
        return 8192
    }
}

// MARK: - GLM API Models
struct GLMChatRequest: Codable {
    let model: String
    let messages: [GLMMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

struct GLMMessage: Codable {
    let role: String
    let content: String
}

struct GLMChatResponse: Codable {
    let choices: [GLMChoice]
    let usage: GLMUsage?
}

struct GLMChoice: Codable {
    let message: GLMMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct GLMUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - GLM Chat Service
@MainActor
class GLMChatService: ObservableObject {
    private(set) var apiKey: String
    private(set) var model: AIModel
    private let session = URLSession.shared
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(apiKey: String = "", model: AIModel = .glm4Flash) {
        self.apiKey = apiKey
        self.model = model
    }
    
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
        errorMessage = nil
    }
    
    func updateModel(_ newModel: AIModel) {
        self.model = newModel
        errorMessage = nil
    }
    
    func updateConfiguration(apiKey: String, model: AIModel) {
        self.apiKey = apiKey
        self.model = model
        errorMessage = nil
    }
    
    func sendMessage(_ userMessage: String, conversationHistory: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GLMError.missingAPIKey
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        // Convert chat history to GLM format
        var glmMessages: [GLMMessage] = []
        
        // Add system message for language learning context
        glmMessages.append(GLMMessage(
            role: "system",
            content: """
            You are a helpful AI language assistant designed to help users practice their language skills. 
            Be encouraging, patient, and provide constructive feedback when appropriate. 
            Keep responses conversational and engaging. Ask follow-up questions to encourage practice.
            If the user makes grammar or vocabulary mistakes, gently correct them in a supportive way.
            """
        ))
        
        // Add conversation history (limit to last 10 messages to avoid token limits)
        let recentHistory = Array(conversationHistory.suffix(10))
        for message in recentHistory {
            glmMessages.append(GLMMessage(
                role: message.isFromUser ? "user" : "assistant",
                content: message.content
            ))
        }
        
        // Add current user message
        glmMessages.append(GLMMessage(role: "user", content: userMessage))
        
        let request = GLMChatRequest(
            model: model.rawValue,
            messages: glmMessages,
            stream: false,
            temperature: 0.7,
            maxTokens: getMaxOutputTokens(for: model)
        )
        
        guard let url = URL(string: model.provider.baseURL) else {
            throw GLMError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GLMError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw GLMError.invalidAPIKey
            }
            
            guard httpResponse.statusCode == 200 else {
                throw GLMError.apiError(httpResponse.statusCode)
            }
            
            let chatResponse = try JSONDecoder().decode(GLMChatResponse.self, from: data)
            
            guard let firstChoice = chatResponse.choices.first else {
                throw GLMError.noResponse
            }
            
            return firstChoice.message.content
            
        } catch let error as GLMError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            let glmError = GLMError.networkError(error.localizedDescription)
            errorMessage = glmError.localizedDescription
            throw glmError
        }
    }
}

// MARK: - GLM Errors
enum GLMError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case apiError(Int)
    case noResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not set. Please add your GLM API key."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidAPIKey:
            return "Invalid API key. Please check your key."
        case .apiError(let code):
            return "API error: \(code)"
        case .noResponse:
            return "Empty response from AI"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
