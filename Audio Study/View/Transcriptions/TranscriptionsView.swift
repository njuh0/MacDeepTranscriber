//
//  TranscriptionsView.swift
//  Audio Study
//
//  Created on 21.06.2025.
//

import SwiftUI
import Foundation

// MARK: - Context Window Limits
private func getContextWindowLimit(for model: AIModel) -> Int {
    switch model.displayName {
    case "GLM-4":
        return 8192
    case "GLM-4-Flash":
        return 8192
    case "ChatGLM3-6B":
        return 8192 // Standard version, could be 32k or 128k for extended versions
    case "Gemini 2.0 Flash":
        return 1_000_000
    default:
        // Fallback based on provider
        switch model.provider {
        case .zhipuAI:
            return 8192 // Default for ZhipuAI models
        case .googleAI:
            return 1_000_000 // Default for Google models (Gemini series)
        }
    }
}

// MARK: - Output Token Limits
private func getMaxOutputTokens(for model: AIModel) -> Int {
    switch model.displayName {
    case "GLM-4":
        return 4095 // Maximum output tokens for GLM-4
    case "GLM-4-Flash":
        return 4095 // Maximum output tokens for GLM-4-Flash  
    case "ChatGLM3-6B":
        return 4095 // Maximum output tokens for ChatGLM3-6B
    case "Gemini 2.0 Flash":
        return 8192 // Much higher limit for Gemini 2.0 Flash
    default:
        // Fallback based on provider
        switch model.provider {
        case .zhipuAI:
            return 4095 // Default for ZhipuAI models
        case .googleAI:
            return 8192 // Default for Google models (higher capacity)
        }
    }
}

// MARK: - Chunk Size Limits
private func getMaxChunkSize(for model: AIModel) -> Int {
    switch model.displayName {
    case "GLM-4":
        return 16_000 // 16k characters for GLM-4
    case "GLM-4-Flash":
        return 16_000 // 16k characters for GLM-4-Flash
    case "ChatGLM3-6B":
        return 16_000 // 16k characters for ChatGLM3-6B
    case "Gemini 2.0 Flash":
        return 32_000 // 32k characters for Gemini 2.0 Flash (much larger capacity)
    default:
        // Fallback based on provider
        switch model.provider {
        case .zhipuAI:
            return 16_000 // Default for ZhipuAI models
        case .googleAI:
            return 32_000 // Default for Google models (higher capacity)
        }
    }
}

struct TranscriptionsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @State private var showSidebar = true // Изначально открыт
    @State private var recordingsFolders: [String] = []
    @State private var selectedFolder: String? = nil
    @State private var transcriptions: [String: String] = [:] // engine: transcription
    
    var body: some View {
        HStack(spacing: 0) {
            // Основное содержимое
            VStack(spacing: 20) {
                if let selectedFolder = selectedFolder {
                    // Показываем выбранную транскрипцию
                    TranscriptionContentView(
                        folderName: selectedFolder,
                        transcriptions: transcriptions,
                        onDeleteTranscription: deleteTranscription,
                        onUpdateTranscriptions: { updatedTranscriptions in
                            self.transcriptions = updatedTranscriptions
                        }
                    )
                } else {
                    // Placeholder когда ничего не выбрано
                    Text("Transcriptions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if recordingsFolders.isEmpty {
                        Text("No transcriptions available")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Placeholder content для пустого состояния
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No recordings with transcriptions found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create some recordings with transcriptions to see them here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    } else {
                        Text("Select a recording from the sidebar")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Placeholder content
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Your transcriptions will appear here")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Select a recording from the sidebar to view transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Сайдбар справа
            if showSidebar && !recordingsFolders.isEmpty {
                RightSidebarView(
                    audioCaptureService: audioCaptureService,
                    recordingsFolders: recordingsFolders,
                    selectedFolder: $selectedFolder,
                    loadTranscriptions: loadTranscriptions
                )
                    .frame(width: 250)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .toolbar {
            if !recordingsFolders.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.right")
                            .foregroundColor(.primary)
                    }
                    .help(showSidebar ? "Hide Sidebar" : "Show Sidebar")
                }
            }
        }
        .onAppear {
            loadRecordingsFolders()
        }
    }
    
    private func deleteTranscription(engine: String) {
        guard let selectedFolder = selectedFolder else { return }
        
        Task {
            let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
            let folderPath = "\(documentsPath)/Recordings/\(selectedFolder)"
            let fileManager = FileManager.default
            
            do {
                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                
                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                        
                        if var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let keyToRemove: String
                            
                            switch engine {
                            case "Apple Speech":
                                keyToRemove = "appleSpeechTranscriptions"
                            case "AI Enhanced":
                                keyToRemove = "aiEnhancedTranscription"
                            default:
                                continue
                            }
                            
                            if json[keyToRemove] != nil {
                                json.removeValue(forKey: keyToRemove)
                                
                                let updatedData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                                try updatedData.write(to: URL(fileURLWithPath: filePath))
                                
                                print("Deleted \(engine) transcription from \(file)")
                                
                                // Обновляем UI на главном потоке
                                await MainActor.run {
                                    var updatedTranscriptions = self.transcriptions
                                    updatedTranscriptions.removeValue(forKey: engine)
                                    self.transcriptions = updatedTranscriptions
                                    
                                    // Если больше нет транскрипций, удаляем всю папку
                                    if updatedTranscriptions.isEmpty {
                                        Task {
                                            await self.deleteFolderIfEmpty(folderPath: folderPath)
                                        }
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            } catch {
                print("Error deleting transcription: \(error)")
            }
        }
    }
    
    private func deleteFolderIfEmpty(folderPath: String) async {
        let fileManager = FileManager.default
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
            
            // Проверяем, остались ли JSON файлы с транскрипциями
            let hasTranscriptionFiles = folderContents.contains { file in
                if file.hasSuffix(".json") && !file.contains("recording_info") {
                    let filePath = "\(folderPath)/\(file)"
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            // Check if there are any transcriptions remaining (only Apple Speech now)
                            return json["appleSpeechTranscriptions"] != nil
                        }
                    } catch {
                        print("Error checking file \(file): \(error)")
                    }
                }
                return false
            }
            
            // Если нет файлов с транскрипциями, удаляем всю папку
            if !hasTranscriptionFiles {
                try fileManager.removeItem(atPath: folderPath)
                print("Deleted empty folder: \(folderPath)")
                
                // Обновляем список папок и сбрасываем выбор
                await MainActor.run {
                    let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                    if let index = self.recordingsFolders.firstIndex(of: folderName) {
                        self.recordingsFolders.remove(at: index)
                        self.selectedFolder = nil
                        self.transcriptions = [:]
                    }
                }
            }
        } catch {
            print("Error checking/deleting folder: \(error)")
        }
    }
    
    private func loadTranscriptions(for folderName: String) {
        print("Loading transcriptions for folder: \(folderName)")
        
        // Очищаем предыдущие транскрипции на главном потоке
        transcriptions = [:]
        
        Task {
            let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
            let folderPath = "\(documentsPath)/Recordings/\(folderName)"
            let fileManager = FileManager.default
            
            var newTranscriptions: [String: String] = [:]
            
            do {
                print("Checking folder path: \(folderPath)")
                
                guard fileManager.fileExists(atPath: folderPath) else {
                    print("Folder does not exist: \(folderPath)")
                    await MainActor.run {
                        self.transcriptions = [:]
                    }
                    return
                }
                
                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                print("Found files in folder: \(folderContents)")
                
                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"
                        print("Reading JSON file: \(filePath)")
                        
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                        
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("JSON structure keys: \(json.keys)")
                            
                            // Parse Apple Speech transcriptions
                            if let appleSpeechTranscriptions = json["appleSpeechTranscriptions"] as? [[String: Any]] {
                                let transcriptions = appleSpeechTranscriptions.compactMap { item in
                                    item["transcription"] as? String
                                }.joined(separator: "\n\n")
                                
                                if !transcriptions.isEmpty {
                                    newTranscriptions["Apple Speech"] = transcriptions
                                    print("Added Apple Speech transcriptions: \(appleSpeechTranscriptions.count) items")
                                }
                            }
                            
                            // Parse AI Enhanced transcription
                            if let aiEnhancedTranscription = json["aiEnhancedTranscription"] as? String {
                                if !aiEnhancedTranscription.isEmpty {
                                    newTranscriptions["AI Enhanced"] = aiEnhancedTranscription
                                    print("Added AI Enhanced transcription")
                                }
                            }
                        } else {
                            print("Failed to parse JSON from file: \(file)")
                        }
                    }
                }
                
                print("Total transcriptions loaded: \(newTranscriptions.count)")
                
                // Обновляем UI на главном потоке
                await MainActor.run {
                    self.transcriptions = newTranscriptions
                }
            } catch {
                print("Error loading transcriptions: \(error)")
                await MainActor.run {
                    self.transcriptions = [:]
                }
            }
        }
    }
    
    private func loadRecordingsFolders() {
        DispatchQueue.global(qos: .userInitiated).async {
            let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
            let recordingsPath = "\(documentsPath)/Recordings"
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: recordingsPath) else {
                print("Recordings folder does not exist at: \(recordingsPath)")
                return
            }
            
            do {
                let folderContents = try fileManager.contentsOfDirectory(atPath: recordingsPath)
                var foldersWithJSON: [String] = []
                
                for item in folderContents {
                    let itemPath = "\(recordingsPath)/\(item)"
                    var isDirectory: ObjCBool = false
                    
                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        // Проверяем, есть ли JSON файлы в папке
                        let folderContents = try fileManager.contentsOfDirectory(atPath: itemPath)
                        if folderContents.contains(where: { $0.hasSuffix(".json") }) {
                            foldersWithJSON.append(item)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.recordingsFolders = foldersWithJSON.sorted()
                }
            } catch {
                print("Error loading recordings folders: \(error)")
            }
        }
    }
}

struct RightSidebarView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    let recordingsFolders: [String]
    @Binding var selectedFolder: String?
    let loadTranscriptions: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Заголовок записей
            if !recordingsFolders.isEmpty {
                Divider()
                
                Text("Recordings")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                
                // Список папок с записями
                List(recordingsFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text(folder)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        selectedFolder == folder ? 
                            Color.accentColor.opacity(0.2) : 
                            Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFolder = folder
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            loadTranscriptions(folder)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .leading
        )
    }
}

struct TranscriptionContentView: View {
    let folderName: String
    let transcriptions: [String: String]
    let onDeleteTranscription: (String) -> Void
    let onUpdateTranscriptions: ([String: String]) -> Void
    @State private var isEnhancing = false
    @State private var enhancedTranscription: String? = nil
    @State private var showEnhancedTranscription = false
    @State private var aiService = UniversalAIChatService()
    @AppStorage("selectedAIModel") private var selectedModel: String = AIModel.glm4Flash.rawValue
    @AppStorage("zhipu_api_key") private var zhipuAPIKey: String = ""
    @AppStorage("google_api_key") private var googleAPIKey: String = ""
    
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
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок с названием записи и кнопкой AI Enhancement
            HStack {
                Text(folderName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Показываем кнопку только если есть оригинальные транскрипции (не AI Enhanced)
                if !transcriptions.isEmpty && !transcriptions.keys.contains("AI Enhanced") {
                    Button(action: {
                        enhanceTranscription()
                    }) {
                        HStack(spacing: 6) {
                            if isEnhancing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.5)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .frame(width: 14, height: 14)
                            }
                            Text("AI Enhance")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isEnhancing)
                    .help("Enhance transcription quality using AI")
                } else if transcriptions.keys.contains("AI Enhanced") {
                    // Кнопка для повторного улучшения
                    Button(action: {
                        enhanceTranscription()
                    }) {
                        HStack(spacing: 6) {
                            if isEnhancing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(0.5)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                    .frame(width: 14, height: 14)
                            }
                            Text("Re-enhance")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isEnhancing)
                    .help("Re-enhance transcription with AI")
                }
            }
            .padding(.top)
            
            if transcriptions.isEmpty {
                // Загрузка
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading transcription...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    // Main transcriptions (Apple Speech only)
                    let originalTranscriptions = transcriptions.filter { $0.key != "AI Enhanced" }
                    
                    if originalTranscriptions.count == 1 {
                        // One original transcription (Apple Speech)
                        let (engine, transcription) = originalTranscriptions.first!
                        SingleTranscriptionView(
                            engine: engine, 
                            transcription: transcription,
                            onDelete: { onDeleteTranscription(engine) }
                        )
                    } else if originalTranscriptions.count > 1 {
                        // Multiple original transcriptions (if extended in future)
                        HStack(spacing: 20) {
                            ForEach(originalTranscriptions.sorted(by: { $0.key < $1.key }), id: \.key) { engine, transcription in
                                SingleTranscriptionView(
                                    engine: engine, 
                                    transcription: transcription,
                                    onDelete: { onDeleteTranscription(engine) }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    
                    // AI Enhanced transcription below the main ones
                    if let aiEnhanced = transcriptions["AI Enhanced"] {
                        VStack(spacing: 12) {
                            HStack {
                                Text("AI Enhanced Result")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            SingleTranscriptionView(
                                engine: "AI Enhanced",
                                transcription: aiEnhanced,
                                onDelete: { deleteAIEnhancedTranscription() }
                            )
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func enhanceTranscription() {
        guard !transcriptions.isEmpty else { return }
        guard !currentAPIKey.isEmpty else {
            print("API key not configured for \(currentModel.displayName)")
            return
        }
        
        print("=== AI Enhancement Started ===")
        print("Folder: \(folderName)")
        print("Session ID: \(UUID().uuidString.prefix(8))")
        print("Selected Model: \(currentModel.displayName) (\(currentModel.rawValue))")
        print("Provider: \(currentModel.provider.displayName)")
        print("Has API Key: \(!currentAPIKey.isEmpty)")
        print("Original transcriptions count: \(transcriptions.filter { $0.key != "AI Enhanced" }.count)")
        
        // Log current model limits
        logModelLimits()
        
        // Uncomment for debugging all models:
        // logAllModelLimits()
        
        isEnhancing = true
        
        Task {
            do {
                // Настраиваем AI сервис с выбранной моделью и ключом
                print("Configuring AI service with model: \(currentModel.displayName)")
                aiService.updateConfiguration(apiKey: currentAPIKey, model: currentModel)
                
                // Создаем prompt для AI, исключая AI Enhanced из исходных данных
                let originalTranscriptions = transcriptions.filter { $0.key != "AI Enhanced" }
                let allTranscriptions = originalTranscriptions.map { engine, text in
                    "=== \(engine) ===\n\(text)"
                }.joined(separator: "\n\n")
                
                // Проверяем длину текста и разбиваем на части если нужно
                let maxChunkSize = getMaxChunkSize(for: currentModel) // Размер чанка зависит от модели
                
                print("Text length: \(allTranscriptions.count) characters, Max chunk size: \(maxChunkSize) characters")
                print("Will use \(allTranscriptions.count <= maxChunkSize ? "single chunk" : "multiple chunks") processing")
                
                let enhancedText: String
                
                if allTranscriptions.count <= maxChunkSize {
                    // Обрабатываем весь текст за один раз
                    enhancedText = try await processTranscriptionChunk(allTranscriptions)
                } else {
                    // Разбиваем на части и обрабатываем каждую
                    enhancedText = try await processLargeTranscription(allTranscriptions, maxChunkSize: maxChunkSize, folderName: folderName)
                }
                
                // Сохраняем AI Enhanced транскрипцию в JSON
                await saveAIEnhancedTranscription(enhancedText)
                
                print("=== AI Enhancement Completed ===")
                print("Enhanced text length: \(enhancedText.count) characters")
                print("Model used: \(currentModel.displayName)")
                
                await MainActor.run {
                    self.isEnhancing = false
                }
            } catch {
                print("=== AI Enhancement Failed ===")
                print("Error enhancing transcription with \(currentModel.displayName): \(error)")
                await MainActor.run {
                    self.isEnhancing = false
                }
            }
        }
    }
    
    private func processTranscriptionChunk(_ text: String) async throws -> String {
        let chunkTokens = estimateTokenCount(text)
        let maxContextTokens = getContextWindowLimit(for: currentModel)
        let contextUsagePercent = min(100, Int(Double(chunkTokens) / Double(maxContextTokens) * 100))
        
        print("=== Processing Single Chunk ===")
        print("Chunk length: \(text.count) characters (~\(chunkTokens) tokens)")
        print("Context usage: \(contextUsagePercent)% (\(chunkTokens)/\(maxContextTokens) tokens)")
        
        let prompt = """
        I have transcriptions from speech recognition engines that contain errors and need cleaning. Please fix and improve this transcription by:

        1. Correcting obvious spelling and grammar mistakes
        2. Fixing punctuation and capitalization
        3. Removing duplicate words or phrases that appear to be recognition errors
        4. Ensuring proper sentence structure and flow
        5. Keeping ALL the original content - do not summarize or shorten

        IMPORTANT: Return the complete cleaned transcription, maintaining all the original information and content length.

        Here are the transcriptions to clean:

        \(text)

        Please provide the complete cleaned transcription:
        """
       
        
        return try await aiService.sendMessage(prompt, conversationHistory: [])
    }
    
    private func processLargeTranscription(_ text: String, maxChunkSize: Int, folderName: String) async throws -> String {
        let sessionId = UUID().uuidString.prefix(8)
        let maxContextTokens = getContextWindowLimit(for: currentModel)
        
        print("=== Processing Large Transcription ===")
        print("Session ID: \(sessionId)")
        print("Folder: \(folderName)")
        print("Model: \(currentModel.displayName) (Provider: \(currentModel.provider.displayName))")
        print("Context window limit: \(maxContextTokens) tokens")
        print("Max chunk size: \(maxChunkSize) characters")
        print("Total text length: \(text.count) characters (~\(estimateTokenCount(text)) tokens)")
        print("Starting conversation with empty history (isolated per recording)")
        
        // Более умное разбиение на равные части с поиском границ
        var chunks: [String] = []
        
        if text.count <= maxChunkSize {
            chunks = [text]
        } else {
            var currentIndex = 0
            
            while currentIndex < text.count {
                let remainingText = String(text[text.index(text.startIndex, offsetBy: currentIndex)...])
                
                if remainingText.count <= maxChunkSize {
                    // Последний кусок
                    chunks.append(remainingText.trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
                
                // Целевая длина чанка
                let targetChunkSize = maxChunkSize
                let minChunkSize = maxChunkSize / 2  // Минимальный размер чанка
                
                // Ищем границу в диапазоне от середины до максимального размера
                let searchStart = max(minChunkSize, targetChunkSize / 2)
                let searchEnd = min(targetChunkSize + 200, remainingText.count)
                
                var bestCutPoint = min(targetChunkSize, remainingText.count)
                
                // Ищем лучшую точку разделения в порядке приоритета
                for i in stride(from: searchEnd, to: searchStart, by: -1) {
                    if i >= remainingText.count { continue }
                    
                    let char = remainingText[remainingText.index(remainingText.startIndex, offsetBy: i)]
                    
                    // 1. Конец предложения (наивысший приоритет)
                    if char == "." || char == "!" || char == "?" {
                        // Проверяем, что после знака есть пробел или конец строки
                        if i + 1 < remainingText.count {
                            let nextChar = remainingText[remainingText.index(remainingText.startIndex, offsetBy: i + 1)]
                            if nextChar == " " || nextChar == "\n" {
                                bestCutPoint = i + 1
                                break
                            }
                        } else {
                            bestCutPoint = i + 1
                            break
                        }
                    }
                    // 2. Новая строка (высокий приоритет)
                    else if char == "\n" {
                        bestCutPoint = i + 1
                        break
                    }
                }
                
                // Если не нашли хорошую границу предложения, ищем знаки препинания
                if bestCutPoint == min(targetChunkSize, remainingText.count) {
                    for i in stride(from: searchEnd, to: searchStart, by: -1) {
                        if i >= remainingText.count { continue }
                        
                        let char = remainingText[remainingText.index(remainingText.startIndex, offsetBy: i)]
                        
                        // 3. Запятая или точка с запятой
                        if char == "," || char == ";" {
                            if i + 1 < remainingText.count {
                                let nextChar = remainingText[remainingText.index(remainingText.startIndex, offsetBy: i + 1)]
                                if nextChar == " " {
                                    bestCutPoint = i + 1
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Если и это не сработало, ищем любой пробел
                if bestCutPoint == min(targetChunkSize, remainingText.count) {
                    for i in stride(from: searchEnd, to: searchStart, by: -1) {
                        if i >= remainingText.count { continue }
                        
                        let char = remainingText[remainingText.index(remainingText.startIndex, offsetBy: i)]
                        
                        // 4. Любой пробел
                        if char == " " {
                            bestCutPoint = i + 1
                            break
                        }
                    }
                }
                
                // Берем кусок до найденной точки разреза
                bestCutPoint = min(bestCutPoint, remainingText.count)
                let chunk = String(remainingText.prefix(bestCutPoint)).trimmingCharacters(in: .whitespacesAndNewlines)
                chunks.append(chunk)
                
                currentIndex += bestCutPoint
            }
        }
        
        print("Processing \(chunks.count) chunks for large transcription (sizes: \(chunks.map { $0.count }))")
        
        // Обрабатываем каждую часть с сохранением контекста
        var enhancedChunks: [String] = []
        var conversationHistory: [(String, String)] = [] // (user_message, ai_response)
        
        for (index, chunk) in chunks.enumerated() {
            // Подсчитываем приблизительное количество токенов в истории
            let historyTokens = estimateTokenCountForHistory(conversationHistory)
            let currentChunkTokens = estimateTokenCount(chunk)
            let promptTokens = estimateTokenCount("""
            I have part \(index + 1) of \(chunks.count) of a speech transcription. Please make MINIMAL corrections only for obvious errors.

            Only fix:
            1. Clear spelling mistakes
            2. Missing spaces between words  
            3. Obvious duplicate words that are recognition errors
            4. Basic punctuation where clearly missing

            DO NOT:
            - Rephrase or rewrite anything
            - Change the speaking style
            - Add words that weren't there
            - Make stylistic changes
            - Summarize or shorten

            Keep this part as close to the original as possible.

            Original part:

            Minimally corrected version:
            """)
            
            let totalRequestTokens = historyTokens + currentChunkTokens + promptTokens
            let contextUsagePercent = min(100, Int(Double(totalRequestTokens) / Double(maxContextTokens) * 100))
            
            // Создаем визуальный индикатор заполненности
            let barLength = 20
            let filledLength = Int(Double(barLength) * Double(contextUsagePercent) / 100.0)
            let emptyLength = barLength - filledLength
            let progressBar = String(repeating: "█", count: filledLength) + String(repeating: "░", count: emptyLength)
            
            print("[Session \(sessionId)] Processing chunk \(index + 1)/\(chunks.count)")
            print("[Session \(sessionId)] Conversation history: \(conversationHistory.count) interactions (~\(historyTokens) tokens)")
            print("[Session \(sessionId)] Current chunk: \(chunk.count) chars (~\(currentChunkTokens) tokens)")
            print("[Session \(sessionId)] Total request: ~\(totalRequestTokens) tokens")
            print("[Session \(sessionId)] Context window: [\(progressBar)] \(contextUsagePercent)% (\(totalRequestTokens)/\(maxContextTokens))")
            
            if contextUsagePercent >= 80 {
                print("[Session \(sessionId)] ⚠️  WARNING: Context window is \(contextUsagePercent)% full - approaching limit!")
            } else if contextUsagePercent >= 60 {
                print("[Session \(sessionId)] ℹ️  INFO: Context window is \(contextUsagePercent)% full")
            }
            
            let prompt = """
            I have part \(index + 1) of \(chunks.count) of a speech transcription. Please make MINIMAL corrections only for obvious errors.

            Only fix:
            1. Clear spelling mistakes
            2. Missing spaces between words  
            3. Obvious duplicate words that are recognition errors
            4. Basic punctuation where clearly missing

            DO NOT:
            - Rephrase or rewrite anything
            - Change the speaking style
            - Add words that weren't there
            - Make stylistic changes
            - Summarize or shorten

            Keep this part as close to the original as possible.

            Original part:

            \(chunk)

            Minimally corrected version:
            """
            
            // Преобразуем историю в формат для AI сервиса
            var chatHistory = conversationHistory.flatMap { userMsg, aiResponse in
                [
                    ChatMessage(content: userMsg, isFromUser: true),
                    ChatMessage(content: aiResponse, isFromUser: false)
                ]
            }
            
            // Если контекстное окно переполнено, сокращаем историю
            if contextUsagePercent >= 90 {
                let maxHistoryMessages = max(2, chatHistory.count / 2) // Оставляем минимум 2 сообщения
                chatHistory = Array(chatHistory.suffix(maxHistoryMessages))
                let reducedTokens = estimateTokenCountForHistory(conversationHistory.suffix(maxHistoryMessages / 2))
                print("[Session \(sessionId)] 🔄 Context window at \(contextUsagePercent)%, reducing history to \(maxHistoryMessages) messages (~\(reducedTokens) tokens)")
            }
            
            print("[Session \(sessionId)] Sending chunk \(index + 1) to AI with \(chatHistory.count) messages in conversation history")
            
            let enhancedChunk = try await aiService.sendMessage(prompt, conversationHistory: chatHistory)
            let cleanedChunk = enhancedChunk.trimmingCharacters(in: .whitespacesAndNewlines)
            enhancedChunks.append(cleanedChunk)
            
            // Добавляем текущий запрос и ответ в историю для следующего чанка
            conversationHistory.append((prompt, cleanedChunk))
            
            print("[Session \(sessionId)] Chunk \(index + 1) processed. Enhanced length: \(cleanedChunk.count) characters")
            print("[Session \(sessionId)] Total conversation history: \(conversationHistory.count) interactions")
            
            // Небольшая пауза между запросами
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        }
        
        // Объединяем обработанные части с пробелом, убирая лишние пробелы
        let result = enhancedChunks.joined(separator: " ")
        let finalResult = result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let maxHistoryTokens = estimateTokenCountForHistory(conversationHistory)
        let maxContextUsagePercent = min(100, Int(Double(maxHistoryTokens) / Double(maxContextTokens) * 100))
        
        // Создаем визуальный индикатор максимального использования контекста
        let barLength = 20
        let filledLength = Int(Double(barLength) * Double(maxContextUsagePercent) / 100.0)
        let emptyLength = barLength - filledLength
        let maxProgressBar = String(repeating: "█", count: filledLength) + String(repeating: "░", count: emptyLength)
        
        print("=== Large Transcription Processing Complete ===")
        print("Session ID: \(sessionId)")
        print("Final enhanced text length: \(finalResult.count) characters")
        print("Total chunks processed: \(enhancedChunks.count)")
        print("Final conversation history size: \(conversationHistory.count) interactions (~\(maxHistoryTokens) tokens)")
        print("Max context window: [\(maxProgressBar)] \(maxContextUsagePercent)% (\(maxHistoryTokens)/\(maxContextTokens))")
        
        return finalResult
    }
    
    private func saveAIEnhancedTranscription(_ enhancedText: String) async {
        let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
        let folderPath = "\(documentsPath)/Recordings/\(folderName)"
        let fileManager = FileManager.default
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
            
            for file in folderContents {
                if file.hasSuffix(".json") && !file.contains("recording_info") {
                    let filePath = "\(folderPath)/\(file)"
                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                    
                    if var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Добавляем или обновляем AI Enhanced транскрипцию
                        json["aiEnhancedTranscription"] = enhancedText
                        
                        let updatedData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                        try updatedData.write(to: URL(fileURLWithPath: filePath))
                        
                        print("Saved AI Enhanced transcription to \(file)")
                        
                        // Обновляем UI на главном потоке
                        await MainActor.run {
                            var updatedTranscriptions = self.transcriptions
                            updatedTranscriptions["AI Enhanced"] = enhancedText
                            self.onUpdateTranscriptions(updatedTranscriptions)
                        }
                        break
                    }
                }
            }
        } catch {
            print("Error saving AI Enhanced transcription: \(error)")
        }
    }
    
    private func deleteAIEnhancedTranscription() {
        let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
        let folderPath = "\(documentsPath)/Recordings/\(folderName)"
        let fileManager = FileManager.default
        
        Task {
            do {
                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                
                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                        
                        if var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if json["aiEnhancedTranscription"] != nil {
                                json.removeValue(forKey: "aiEnhancedTranscription")
                                
                                let updatedData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                                try updatedData.write(to: URL(fileURLWithPath: filePath))
                                
                                print("Deleted AI Enhanced transcription from \(file)")
                                
                                // Обновляем UI на главном потоке
                                await MainActor.run {
                                    var updatedTranscriptions = self.transcriptions
                                    updatedTranscriptions.removeValue(forKey: "AI Enhanced")
                                    self.onUpdateTranscriptions(updatedTranscriptions)
                                }
                                break
                            }
                        }
                    }
                }
            } catch {
                print("Error deleting AI Enhanced transcription: \(error)")
            }
        }
    }
    
    // MARK: - Debug Functions
    
    func logAllModelLimits() {
        print("=== All AI Model Limits ===")
        
        for model in AIModel.allCases {
            let contextLimit = getContextWindowLimit(for: model)
            let outputLimit = getMaxOutputTokens(for: model)
            let chunkSize = getMaxChunkSize(for: model)
            
            print("🤖 \(model.displayName) (\(model.provider.displayName)):")
            print("   Context: \(contextLimit) tokens | Output: \(outputLimit) tokens | Chunk: \(chunkSize) chars")
        }
        
        print("===============================")
    }
    
    // MARK: - Helper Functions
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Более точная оценка токенов:
        // - Английский текст: ~4 символа на токен
        // - Русский текст: ~6-8 символов на токен (кириллица менее эффективна)
        // - Пробелы и знаки препинания учитываются отдельно
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let avgCharactersPerToken: Double
        
        // Определяем тип текста по первым словам
        let sampleText = words.prefix(10).joined()
        let cyrillicRange = sampleText.range(of: "[а-яё]", options: [.regularExpression, .caseInsensitive])
        
        if cyrillicRange != nil {
            // Русский текст - менее эффективное токенизирование
            avgCharactersPerToken = 6.5
        } else {
            // Английский или другой латинский текст
            avgCharactersPerToken = 4.0
        }
        
        let estimatedTokens = Double(text.count) / avgCharactersPerToken
        
        // Добавляем токены для структурных элементов (знаки препинания, переводы строк)
        let punctuationCount = text.filter { ".,!?;:".contains($0) }.count
        let newlineCount = text.filter { $0.isNewline }.count
        
        return Int(ceil(estimatedTokens + Double(punctuationCount) * 0.2 + Double(newlineCount) * 0.5))
    }
    
    private func estimateTokenCountForHistory(_ history: [(String, String)]) -> Int {
        let totalText = history.flatMap { [$0.0, $0.1] }.joined(separator: " ")
        return estimateTokenCount(totalText)
    }
    
    func logModelLimits() {
        let contextLimit = getContextWindowLimit(for: currentModel)
        let outputLimit = getMaxOutputTokens(for: currentModel)
        let chunkSize = getMaxChunkSize(for: currentModel)
        let ratio = Double(contextLimit) / Double(outputLimit)
        
        print("=== Model Limits for \(currentModel.displayName) ===")
        print("Provider: \(currentModel.provider.displayName)")
        print("Context window limit: \(contextLimit) tokens")
        print("Max output tokens: \(outputLimit) tokens")
        print("Max chunk size: \(chunkSize) characters")
        print("Context/Output ratio: \(String(format: "%.1f", ratio))x")
        
        if currentModel.provider == .googleAI {
            print("ℹ️  Google AI models have very large context windows and chunk sizes")
        } else {
            print("⚠️  ZhipuAI models have smaller context windows - optimal chunking applied")
        }
        print("=====================================")
    }
}

struct SingleTranscriptionView: View {
    let engine: String
    let transcription: String
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок движка с кнопкой удаления
            HStack {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                    Text(engine.capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Счетчик символов
                    Text("(\(transcription.count) chars)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete \(engine) transcription")
            }
            
            Divider()
            
            // Текст транскрипции
            ScrollView {
                Text(transcription)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

#Preview {
    TranscriptionsView(audioCaptureService: AudioCaptureService())
}
