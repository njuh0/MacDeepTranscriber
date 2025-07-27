//
//  AIChatView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    init(content: String, isFromUser: Bool) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
    }
}

// MARK: - AI Chat View
struct AIChatView: View {
    @StateObject private var aiService = UniversalAIChatService()
    @State private var messages: [ChatMessage] = []
    @State private var currentMessage: String = ""
    @FocusState private var isInputFocused: Bool
    
    @AppStorage("selectedAIModel") private var selectedModel: String = AIModel.glm4Flash.rawValue
    @AppStorage("zhipu_api_key") private var zhipuAPIKey: String = ""
    @AppStorage("google_api_key") private var googleAPIKey: String = ""
    @AppStorage("custom_prompt_enabled") private var customPromptEnabled: Bool = false
    @AppStorage("custom_prompt_text") private var customPromptText: String = ""
    
    private var currentModel: AIModel {
        AIModel(rawValue: selectedModel) ?? .glm4Flash
    }
    
    private var currentAPIKey: String {
        switch currentModel.provider {
        case .zhipuAI:
            return zhipuAPIKey
        case .googleAI:
            return googleAPIKey
        }
    }
    
    private var isLoading: Bool {
        aiService.isLoading
    }
    
    @State private var showSidebar = true
    @State private var recordingsFolders: [String] = []
    @State private var selectedFolders: Set<String> = []
    @State private var transcriptions: [String: String] = [:]
    @State private var enhancedFolders: [String: Bool] = [:]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                // Messages List
                messagesView
                
                Divider()
                
                // Input Area
                inputView
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            if showSidebar {
                AIChatRightSidebarView(
                    recordingsFolders: recordingsFolders,
                    selectedFolders: $selectedFolders,
                    enhancedFolders: enhancedFolders
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }
        }
        .onAppear {
            loadConfiguration()
            loadRecordingsFolders()
            for folder in selectedFolders {
                loadTranscriptions(for: folder)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiSettingsChanged)) { _ in
            loadConfiguration()
        }
        .onChange(of: selectedFolders) { folders in
            for folder in folders {
                if transcriptions[folder] == nil {
                    loadTranscriptions(for: folder)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .foregroundColor(.primary)
                }
                .help(showSidebar ? "Hide Right Sidebar" : "Show Right Sidebar")
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Language Assistant")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Text("Model:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currentModel.displayName)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if currentAPIKey.isEmpty {
                        Text("• No API Key")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("• Ready")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: copyAllMessages) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy all messages")
                .disabled(messages.isEmpty)
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear chat")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        Group {
            if messages.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                loadingIndicator
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Input View
    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $currentMessage, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isInputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 16) 
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onSubmit {
                    sendMessage()
                }
                .disabled(isLoading)
            
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(canSendMessage ? Color.blue : Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSendMessage)
            .scaleEffect(canSendMessage ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: canSendMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("Start a conversation")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Ask me anything to practice your language skills!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    // MARK: - Loading Indicator
    private var loadingIndicator: some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isLoading ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isLoading
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var canSendMessage: Bool {
        !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    // MARK: - Methods
    private func sendMessage() {
        guard canSendMessage else { return }

        // Check if API key is set
        if currentAPIKey.isEmpty {
            // Show message to go to settings
            messages.append(ChatMessage(
                content: "Please configure your API key in Settings to start chatting with AI.",
                isFromUser: false
            ))
            return
        }

        let messageText = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add user message to the UI
        messages.append(ChatMessage(content: messageText, isFromUser: true))
        currentMessage = ""

        // Get conversation history for AI (excluding the current message)
        let conversationHistoryForAI = Array(messages.dropLast())

        // Construct the prompt with selected transcriptions
        var prompt = messageText
        if !selectedFolders.isEmpty {
            let selectedTranscriptions = selectedFolders.compactMap { transcriptions[$0] }
            if !selectedTranscriptions.isEmpty {
                if selectedTranscriptions.count == 1 {
                    prompt = "Transcription: \(selectedTranscriptions[0])\n\nUser message: \(messageText)"
                } else {
                    let transcriptionList = selectedTranscriptions.enumerated().map { (index, transcription) in
                        "Transcription \(index + 1):\n\(transcription)"
                    }.joined(separator: "\n\n")
                    prompt = "\(transcriptionList)\n\nUser message: \(messageText)"
                }
            }
        }

        // Send to AI API
        Task {
            do {
                let customPrompt = customPromptEnabled ? customPromptText : nil
                let aiResponse = try await aiService.sendMessage(prompt, conversationHistory: conversationHistoryForAI, customPrompt: customPrompt)
                await MainActor.run {
                    messages.append(ChatMessage(content: aiResponse, isFromUser: false))
                }
            } catch {
                await MainActor.run {
                    // Add error message to chat
                    messages.append(ChatMessage(
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isFromUser: false
                    ))
                }
            }
        }
    }
    
    private func clearChat() {
        messages.removeAll()
    }
    
    private func copyAllMessages() {
        let chatText = messages.map { message in
            let sender = message.isFromUser ? "You" : "Assistant"
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timestamp = formatter.string(from: message.timestamp)
            return "[\(timestamp)] \(sender): \(message.content)"
        }.joined(separator: "\n\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(chatText, forType: .string)
    }
    
    private func loadConfiguration() {
        aiService.updateConfiguration(apiKey: currentAPIKey, model: currentModel)
    }

    private func loadRecordingsFolders() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
                print("Could not get documents directory")
                return
            }
            let recordingsPath = "\(documentsPath)/Recordings"
            let fileManager = FileManager.default

            guard fileManager.fileExists(atPath: recordingsPath) else {
                print("Recordings folder does not exist at: \(recordingsPath)")
                return
            }

            do {
                let folderContents = try fileManager.contentsOfDirectory(atPath: recordingsPath)
                var foldersWithJSON: [String] = []
                var newEnhancedFolders: [String: Bool] = [:]

                for item in folderContents {
                    let itemPath = "\(recordingsPath)/\(item)"
                    var isDirectory: ObjCBool = false

                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        let subfolderContents = try fileManager.contentsOfDirectory(atPath: itemPath)
                        var hasJson = false
                        var isEnhanced = false

                        for file in subfolderContents {
                            if file.hasSuffix(".json") && !file.contains("recording_info") {
                                hasJson = true
                                let filePath = "\(itemPath)/\(file)"
                                do {
                                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                    if let aiTranscription = json?["aiEnhancedTranscription"] as? String, !aiTranscription.isEmpty {
                                        isEnhanced = true
                                        break
                                    }
                                } catch {
                                    print("Error reading JSON file \(file) in \(item): \(error)")
                                }
                            }
                        }

                        if hasJson {
                            foldersWithJSON.append(item)
                            if isEnhanced {
                                newEnhancedFolders[item] = true
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.recordingsFolders = foldersWithJSON.sorted()
                    self.enhancedFolders = newEnhancedFolders
                }
            } catch {
                print("Error loading recordings folders: \(error)")
            }
        }
    }

    private func loadTranscriptions(for folderName: String) {
        print("Loading transcriptions for folder: \(folderName)")

        Task {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
                print("Could not get documents directory")
                return
            }
            let folderPath = "\(documentsPath)/Recordings/\(folderName)"
            let fileManager = FileManager.default

            var newTranscriptions: [String: String] = [:]

            do {
                print("Checking folder path: \(folderPath)")

                guard fileManager.fileExists(atPath: folderPath) else {
                    print("Folder does not exist: \(folderPath)")
                    return
                }

                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                print("Folder contents: \(folderContents)")

                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"

                        do {
                            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                            // Process appleSpeechTranscriptions array
                            if let appleSpeechTranscriptions = json?["appleSpeechTranscriptions"] as? [[String: Any]] {
                                let transcriptions = appleSpeechTranscriptions.compactMap { item in
                                    return item["transcription"] as? String
                                }
                                let combinedTranscription = transcriptions.joined(separator: " ")
                                if !combinedTranscription.isEmpty {
                                    newTranscriptions["Apple Speech"] = combinedTranscription
                                    print("Found Apple Speech transcription in \(file): \(combinedTranscription.prefix(50))...")
                                }
                            }

                            if let aiTranscription = json?["aiEnhancedTranscription"] as? String, !aiTranscription.isEmpty {
                                newTranscriptions["AI Enhanced"] = aiTranscription
                                print("Found AI Enhanced transcription in \(file): \(aiTranscription.prefix(50))...")
                                await MainActor.run {
                                    self.enhancedFolders[folderName] = true
                                }
                            }
                        } catch {
                            print("Error reading JSON file \(file): \(error)")
                        }
                    }
                }

                await MainActor.run {
                    if let transcription = newTranscriptions["AI Enhanced"] ?? newTranscriptions["Apple Speech"] {
                        self.transcriptions[folderName] = transcription
                    }
                }
            } catch {
                print("Error loading transcriptions from folder \(folderName): \(error)")
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var showCopyButton = false
    @State private var showCopyConfirmation = false
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if !message.isFromUser {
                        copyButton
                    }
                    
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(message.isFromUser ? Color.blue : Color.gray.opacity(0.1))
                        .foregroundColor(message.isFromUser ? .white : .primary)
                        .cornerRadius(16)
                        .textSelection(.enabled) // Allows text selection
                    
                    if message.isFromUser {
                        copyButton
                    }
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyButton = hovering
            }
        }
    }
    
    private var copyButton: some View {
        Button(action: copyMessage) {
            Image(systemName: showCopyConfirmation ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundColor(showCopyConfirmation ? .green : .gray)
                .font(.system(size: 14))
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(showCopyButton ? 1.0 : 0.0)
        .help("Copy message")
        .onAppear {
            if showCopyConfirmation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCopyConfirmation = false
                    }
                }
            }
        }
    }
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopyConfirmation = true
        }
        
        // Hide confirmation after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopyConfirmation = false
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AIChatView()
}