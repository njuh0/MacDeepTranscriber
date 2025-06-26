//
//  UniversalAIChatService.swift
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

// MARK: - Universal AI Chat Service
@MainActor
class UniversalAIChatService: ObservableObject {
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
    
    func sendMessage(_ userMessage: String, conversationHistory: [ChatMessage], customPrompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        // Prepare system instruction
        let systemInstruction: String
        if let customPrompt = customPrompt, !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            systemInstruction = customPrompt
        } else {
            systemInstruction = """
            You are a helpful AI assistant. You will receive text that has been transcribed from speech-to-text. 
            Please note that this transcribed text may not be perfect and some words might be incorrectly recognized or misheard. 
            Be understanding of potential transcription errors and try to interpret the intended meaning when responding. 
            Provide clear, helpful, and conversational responses based on what you understand from the transcribed input.
            """
        }
        
        switch model.provider {
        case .zhipuAI:
            return try await sendToZhipuAI(userMessage, conversationHistory: conversationHistory, systemInstruction: systemInstruction)
        case .googleAI:
            return try await sendToGoogleAI(userMessage, conversationHistory: conversationHistory, systemInstruction: systemInstruction)
        }
    }
    
    // MARK: - Zhipu AI Implementation
    private func sendToZhipuAI(_ userMessage: String, conversationHistory: [ChatMessage], systemInstruction: String) async throws -> String {
        // Convert chat history to GLM format
        var glmMessages: [GLMMessage] = []
        
        // Add system message
        glmMessages.append(GLMMessage(
            role: "system",
            content: systemInstruction
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
            throw AIError.invalidURL
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
                throw AIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw AIError.invalidAPIKey
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.apiError(httpResponse.statusCode)
            }
            
            let chatResponse = try JSONDecoder().decode(GLMChatResponse.self, from: data)
            
            guard let firstChoice = chatResponse.choices.first else {
                throw AIError.noResponse
            }
            
            return firstChoice.message.content
            
        } catch let error as AIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            let aiError = AIError.networkError(error.localizedDescription)
            errorMessage = aiError.localizedDescription
            throw aiError
        }
    }
    
    // MARK: - Google AI Implementation
    private func sendToGoogleAI(_ userMessage: String, conversationHistory: [ChatMessage], systemInstruction: String) async throws -> String {
        // Convert chat history to Gemini format
        var contents: [GeminiContent] = []
        
        // Add conversation history
        let recentHistory = Array(conversationHistory.suffix(10))
        for message in recentHistory {
            contents.append(GeminiContent(
                role: message.isFromUser ? "user" : "model",
                parts: [GeminiPart(text: message.content)]
            ))
        }
        
        // Add current user message
        contents.append(GeminiContent(
            role: "user",
            parts: [GeminiPart(text: userMessage)]
        ))
        
        let systemInstructionContent = GeminiContent(
            role: "user",
            parts: [GeminiPart(text: systemInstruction)]
        )
        
        let request = GeminiChatRequest(
            contents: contents,
            systemInstruction: systemInstructionContent,
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: getMaxOutputTokens(for: model)
            )
        )
        
        guard let url = URL(string: "\(model.provider.baseURL)/\(model.rawValue):generateContent?key=\(apiKey)") else {
            throw AIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw AIError.invalidAPIKey
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.apiError(httpResponse.statusCode)
            }
            
            let chatResponse = try JSONDecoder().decode(GeminiChatResponse.self, from: data)
            
            guard let firstCandidate = chatResponse.candidates.first,
                  let firstPart = firstCandidate.content.parts.first else {
                throw AIError.noResponse
            }
            
            return firstPart.text
            
        } catch let error as AIError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            let aiError = AIError.networkError(error.localizedDescription)
            errorMessage = aiError.localizedDescription
            throw aiError
        }
    }
}

// MARK: - Gemini API Models
struct GeminiChatRequest: Codable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig?
}

struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
}

struct GeminiChatResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

// MARK: - Universal AI Errors
enum AIError: LocalizedError {
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
            return "API ключ не установлен. Пожалуйста, настройте API ключ в Settings."
        case .invalidURL:
            return "Неверный URL API"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .invalidAPIKey:
            return "Неверный API ключ. Проверьте правильность ключа в Settings."
        case .apiError(let code):
            return "Ошибка API: \(code)"
        case .noResponse:
            return "Пустой ответ от AI"
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        }
    }
}
