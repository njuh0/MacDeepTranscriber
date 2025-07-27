//
//  SettingsView.swift
//  MacDeepTranscriber
//
//  Created on 20.06.2025.
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("selectedAIModel") private var selectedModel: String = AIModel.glm4Flash.rawValue
    @AppStorage("zhipu_api_key") private var zhipuAPIKey: String = ""
    @AppStorage("google_api_key") private var googleAPIKey: String = ""
    @AppStorage("custom_prompt_enabled") private var customPromptEnabled: Bool = false
    @AppStorage("custom_prompt_text") private var customPromptText: String = ""
    
    @State private var tempAPIKey: String = ""
    @State private var showingAPIKeyField: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    @State private var isAPIKeyVisible: Bool = false // New state for showing/hiding API key
    
    private var currentModel: AIModel {
        AIModel(rawValue: selectedModel) ?? .glm4Flash
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // AI Model Selection
                    modelSelectionSection
                    
                    // API Configuration
                    if showingAPIKeyField {
                        apiConfigurationSection
                    }
                    
                    // Custom Prompt Section
                    customPromptSection
                    
                    // Information Section
                    informationSection
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") { }
        } message: {
            Text("Your AI model and API key have been saved successfully.")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Configure AI models and API keys")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Model Selection Section
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Model")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select AI Model")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Model Selection Cards in a grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(AIModel.allCases) { model in
                        ModelSelectionCard(
                            model: model,
                            isSelected: model.rawValue == selectedModel,
                            onSelect: {
                                selectModel(model)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - API Configuration Section
    private var apiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("API Configuration")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Provider Info
                HStack {
                    Text("Provider:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(currentModel.provider.displayName)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Free Tier Badge
                if currentModel.hasFreeTier {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(currentModel.freeTierDetails)
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // API Key Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        if isAPIKeyVisible {
                            TextField("Enter your API key", text: $tempAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    saveAPIKey()
                                }
                        } else {
                            SecureField("Enter your API key", text: $tempAPIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    saveAPIKey()
                                }
                        }
                        
                        Button(action: {
                            isAPIKeyVisible.toggle()
                        }) {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(isAPIKeyVisible ? "Hide API key" : "Show API key")
                    }
                    
                    if !tempAPIKey.isEmpty || !getCurrentAPIKey().isEmpty {
                        HStack {
                            Button("Save") {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(tempAPIKey.isEmpty)
                            
                            if !getCurrentAPIKey().isEmpty {
                                Button("Clear") {
                                    clearAPIKey()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                // API Key Status
                HStack {
                    Image(systemName: getCurrentAPIKey().isEmpty ? "exclamationmark.circle" : "checkmark.circle")
                        .foregroundColor(getCurrentAPIKey().isEmpty ? .orange : .green)
                    
                    Text(getCurrentAPIKey().isEmpty ? "API key not configured" : "API key configured")
                        .font(.caption)
                        .foregroundColor(getCurrentAPIKey().isEmpty ? .orange : .green)
                }
                
                // Provider Links
                VStack(alignment: .leading, spacing: 6) {
                    Link("🔑 Get API Key", destination: URL(string: currentModel.provider.signupURL)!)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Link("📖 API Documentation", destination: URL(string: currentModel.provider.documentationURL)!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Information Section
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Information")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    title: "Current Model",
                    value: currentModel.displayName,
                    description: currentModel.description
                )
                
                InfoRow(
                    title: "Provider",
                    value: currentModel.provider.displayName,
                    description: "AI service provider"
                )
                
                InfoRow(
                    title: "Security",
                    value: "Local Storage",
                    description: "API keys are stored securely on your device"
                )
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Custom Prompt Section
    private var customPromptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.purple)
                Text("Custom Prompt")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Enable/Disable Toggle
                HStack {
                    Text("Enable Custom Prompt")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: $customPromptEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: customPromptEnabled) { enabled in
                            // Notify other views about prompt settings change
                            NotificationCenter.default.post(
                                name: .aiSettingsChanged,
                                object: nil,
                                userInfo: [
                                    "customPromptEnabled": enabled,
                                    "customPrompt": customPromptText
                                ]
                            )
                        }
                }
                
                // Prompt Text Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Prompt Text")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(customPromptEnabled ? .primary : .secondary)
                    
                    if customPromptEnabled {
                        TextEditor(text: $customPromptText)
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: customPromptText) { newValue in
                                // Notify other views about prompt text change
                                NotificationCenter.default.post(
                                    name: .aiSettingsChanged,
                                    object: nil,
                                    userInfo: [
                                        "customPromptEnabled": customPromptEnabled,
                                        "customPrompt": newValue
                                    ]
                                )
                            }
                    } else {
                        Text("You are a helpful AI assistant. You will receive text that has been transcribed from speech-to-text. Please note that this transcribed text may not be perfect and some words might be incorrectly recognized or misheard. Be understanding of potential transcription errors and try to interpret the intended meaning when responding. Provide clear, helpful, and conversational responses based on what you understand from the transcribed input.")
                            .frame(minHeight: 80, maxHeight: 120, alignment: .topLeading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Help Text
                Text(customPromptEnabled ? 
                     "Enter your custom instructions for the AI assistant. This will override the default transcription processing behavior." :
                     "Enable to provide custom instructions for the AI assistant instead of using default transcription handling.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Methods
    private func getCurrentAPIKey() -> String {
        switch currentModel.provider {
        case .zhipuAI:
            return zhipuAPIKey
        case .googleAI:
            return googleAPIKey
        }
    }
    
    private func loadSettings() {
        tempAPIKey = getCurrentAPIKey()
        showingAPIKeyField = currentModel.requiresAPIKey
        isAPIKeyVisible = false // Reset visibility for security
    }
    
    private func selectModel(_ model: AIModel) {
        selectedModel = model.rawValue
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingAPIKeyField = model.requiresAPIKey
        }
        
        // Load the appropriate API key for the selected model
        tempAPIKey = getCurrentAPIKey()
        isAPIKeyVisible = false // Reset visibility when changing models
    }
    
    private func saveAPIKey() {
        switch currentModel.provider {
        case .zhipuAI:
            zhipuAPIKey = tempAPIKey
        case .googleAI:
            googleAPIKey = tempAPIKey
        }
        
        showingSaveConfirmation = true
        
        // Post notification for other views to update
        NotificationCenter.default.post(
            name: .aiSettingsChanged,
            object: nil,
            userInfo: [
                "model": currentModel.rawValue,
                "apiKey": tempAPIKey
            ]
        )
    }
    
    private func clearAPIKey() {
        tempAPIKey = ""
        switch currentModel.provider {
        case .zhipuAI:
            zhipuAPIKey = ""
        case .googleAI:
            googleAPIKey = ""
        }
        
        NotificationCenter.default.post(
            name: .aiSettingsChanged,
            object: nil,
            userInfo: [
                "model": currentModel.rawValue,
                "apiKey": ""
            ]
        )
    }
}

// MARK: - Model Selection Card
struct ModelSelectionCard: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with model name and checkmark
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(model.provider.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                // Model description
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Free tier badge
                HStack {
                    if model.hasFreeTier {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(model.freeTierDetails)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Model type indicator
                    Text("Text")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle()) // Make entire card clickable
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let aiSettingsChanged = Notification.Name("aiSettingsChanged")
}

#Preview {
    SettingsView()
}
