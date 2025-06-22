//
//  AIModel.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import Foundation

// MARK: - AI Model Types
enum AIModel: String, CaseIterable, Identifiable {
    case glm4Flash = "glm-4-flash"
    case gemini2Flash = "gemini-2.0-flash-exp"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .glm4Flash:
            return "GLM-4-Flash"
        case .gemini2Flash:
            return "Gemini 2.0 Flash"
        }
    }
    
    var description: String {
        switch self {
        case .glm4Flash:
            return "Fastest AI model from Zhipu AI, optimized for quick responses"
        case .gemini2Flash:
            return "Google's latest AI model with enhanced reasoning and large context window"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .glm4Flash:
            return .zhipuAI
        case .gemini2Flash:
            return .googleAI
        }
    }
    
    var requiresAPIKey: Bool {
        return true
    }
    
    var hasFreeTier: Bool {
        return true
    }
    
    var freeTierDetails: String {
        switch self {
        case .glm4Flash:
            return "Free tier: 1M tokens/month"
        case .gemini2Flash:
            return "Free tier: 1500 requests/day"
        }
    }
}

// MARK: - AI Provider Types
enum AIProvider: String, CaseIterable {
    case zhipuAI = "zhipu"
    case googleAI = "google"
    
    var displayName: String {
        switch self {
        case .zhipuAI:
            return "Zhipu AI (智谱AI)"
        case .googleAI:
            return "Google AI Studio"
        }
    }
    
    var baseURL: String {
        switch self {
        case .zhipuAI:
            return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .googleAI:
            return "https://generativelanguage.googleapis.com/v1beta/models"
        }
    }
    
    var signupURL: String {
        switch self {
        case .zhipuAI:
            return "https://open.bigmodel.cn/"
        case .googleAI:
            return "https://aistudio.google.com/app/apikey"
        }
    }
    
    var documentationURL: String {
        switch self {
        case .zhipuAI:
            return "https://open.bigmodel.cn/dev/howuse/introduction"
        case .googleAI:
            return "https://ai.google.dev/gemini-api/docs"
        }
    }
}
