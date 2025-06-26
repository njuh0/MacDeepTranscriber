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
    switch model {
    case .glm4Flash:
        return 8192
    case .gemini2Flash:
        return 1_000_000
    }
}

// MARK: - Output Token Limits
private func getMaxOutputTokens(for model: AIModel) -> Int {
    switch model {
    case .glm4Flash:
        return 4095
    case .gemini2Flash:
        return 8192
    }
}

// MARK: - Chunk Size Limits
private func getMaxChunkSize(for model: AIModel) -> Int {
    switch model {
    case .glm4Flash:
        return 16_000 // 16k characters for GLM-4-Flash
    case .gemini2Flash:
        return 32_000 // 32k characters for Gemini 2.0 Flash (much larger capacity)
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
                        audioCaptureService.openRecordingsFolder()
                    }) {
                        Image(systemName: "folder")
                            .font(.title2)
                    }
                    .help("Open Recordings Folder")
                }
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
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not get documents directory")
                return
            }
            let folderPath = documentsURL.appendingPathComponent("Recordings").appendingPathComponent(selectedFolder).path
            let fileManager = FileManager.default
            
            do {
                if engine == "Apple Speech" {
                    // Если удаляем Apple Speech, удаляем всю папку независимо от AI Enhanced
                    try fileManager.removeItem(atPath: folderPath)
                    print("Deleted entire folder \(folderPath) after removing Apple Speech transcription")
                    
                    // Обновляем UI на главном потоке
                    await MainActor.run {
                        let folderName = URL(fileURLWithPath: folderPath).lastPathComponent
                        if let index = self.recordingsFolders.firstIndex(of: folderName) {
                            self.recordingsFolders.remove(at: index)
                        }
                        self.selectedFolder = nil
                        self.transcriptions = [:]
                    }
                } else {
                    // Для AI Enhanced удаляем только этот ключ из JSON
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
                                        self.transcriptions = updatedTranscriptions
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Error deleting transcription: \(error)")
            }
        }
    }
    
    private func loadTranscriptions(for folderName: String) {
        print("Loading transcriptions for folder: \(folderName)")
        
        // Очищаем предыдущие транскрипции на главном потоке
        transcriptions = [:]
        
        Task {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not get documents directory")
                return
            }
            let folderPath = documentsURL.appendingPathComponent("Recordings").appendingPathComponent(folderName).path
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
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not get documents directory")
                return
            }
            let recordingsPath = documentsURL.appendingPathComponent("Recordings").path
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
                    VStack(alignment: .trailing, spacing: 4) {
                        // Отображение текущей модели
                        Text("Model: \(currentModel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
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
                        .help("Enhance transcription quality using \(currentModel.displayName)")
                    }
                } else if transcriptions.keys.contains("AI Enhanced") {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Отображение текущей модели
                        Text("Model: \(currentModel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
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
                        .help("Re-enhance transcription with \(currentModel.displayName)")
                    }
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
                    let rawEnhanced = try await processTranscriptionChunk(allTranscriptions)
                    
                    // Для отладки: временно отключаем удаление дубликатов
                    let shouldRemoveDuplicates = false // Изменить на true для включения удаления дубликатов
                    enhancedText = shouldRemoveDuplicates ? removeDuplicateSegments(rawEnhanced) : rawEnhanced
                    
                    if !shouldRemoveDuplicates {
                        print("⚠️  Duplicate removal is DISABLED for debugging")
                    }
                } else {
                    // Разбиваем на части и обрабатываем каждую
                    let rawEnhanced = try await processLargeTranscription(allTranscriptions, maxChunkSize: maxChunkSize, folderName: folderName)
                    
                    // Для отладки: временно отключаем удаление дубликатов
                    let shouldRemoveDuplicates = false // Изменить на true для включения удаления дубликатов
                    enhancedText = shouldRemoveDuplicates ? removeDuplicateSegments(rawEnhanced) : rawEnhanced
                    
                    if !shouldRemoveDuplicates {
                        print("⚠️  Duplicate removal is DISABLED for debugging")
                    }
                }
                
                // Сохраняем AI Enhanced транскрипцию в JSON
                await saveAIEnhancedTranscription(enhancedText)
                
                print("=== AI Enhancement Completed ===")
                print("Original text length: \(allTranscriptions.count) characters")
                print("Enhanced text length: \(enhancedText.count) characters")
                print("Model used: \(currentModel.displayName)")
                print("Duplicates were processed and removed")
                
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
        print("Detected language pattern: \(detectLanguage(in: text))")
        print("Language will be auto-detected by AI model")
        
        let prompt = """
        I have a speech recognition transcription that contains errors and needs cleaning. Please analyze the language and fix this transcription by:

        1. Automatically detecting the language of the transcription
        2. Correcting obvious spelling mistakes and typos in that language
        3. Fixing punctuation, capitalization, and spacing according to language rules
        4. Removing duplicate sentences, paragraphs or phrases that appear to be recognition errors
        5. Completing cut-off words or sentences that end abruptly
        6. Ensuring proper sentence structure and natural flow for the detected language
        7. Fixing names and technical terms that were misrecognized
        8. Adding missing punctuation marks appropriate for the language
        9. Keeping ALL the original unique content - do not summarize or shorten

        IMPORTANT: 
        - First detect the language, then apply language-specific corrections
        - Return the complete cleaned transcription without duplications
        - Maintain all the original unique information and meaning
        - If text is repeated multiple times, keep only one clean version
        - Complete any sentences that end abruptly or are cut off
        - Ensure natural language flow according to the detected language's grammar rules
        - Preserve the original language - do not translate

        Here is the transcription to clean:

        \(text)

        Please provide the complete cleaned transcription in the same language:
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
        print("Detected language pattern: \(detectLanguage(in: text))")
        print("Language will be auto-detected by AI model for each chunk")
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
            I have part \(index + 1) of \(chunks.count) of a speech transcription. Please make corrections for errors while preserving the original meaning and language.

            Please:
            1. Automatically detect the language of this text part
            2. Fix clear spelling mistakes and typos in that language
            3. Correct missing spaces between words  
            4. Remove obvious duplicate words or phrases that are recognition errors
            5. Add basic punctuation where clearly missing according to language rules
            6. Complete cut-off words or incomplete sentences
            7. Fix names and technical terms that were misrecognized

            IMPORTANT RULES:
            - Keep the original content, meaning, and language intact
            - Do NOT translate to another language
            - Do NOT rephrase or rewrite in your own words
            - Do NOT change the speaking style or add explanations
            - Do NOT summarize or shorten the content
            - If this part seems to repeat content from previous parts, still process it (duplicates will be handled separately)
            - Complete any sentences that end abruptly
            - Apply language-specific grammar and punctuation rules

            Original part \(index + 1)/\(chunks.count):

            \(chunk)

            Corrected version (same language):
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
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not get documents directory")
            return
        }
        let folderPath = documentsURL.appendingPathComponent("Recordings").appendingPathComponent(folderName).path
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
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not get documents directory")
            return
        }
        let folderPath = documentsURL.appendingPathComponent("Recordings").appendingPathComponent(folderName).path
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
    
    // MARK: - Language Detection Helper
    
    private func detectLanguage(in text: String) -> String {
        let sampleText = text.prefix(200) // Первые 200 символов для определения
        
        // Проверяем различные языки
        if sampleText.range(of: "[а-яёі]", options: [.regularExpression, .caseInsensitive]) != nil {
            return "Cyrillic (Russian/Ukrainian/etc.)"
        } else if sampleText.range(of: "[\\u4e00-\\u9fff\\u3040-\\u309f\\u30a0-\\u30ff]", options: [.regularExpression]) != nil {
            return "CJK (Chinese/Japanese/Korean)"
        } else if sampleText.range(of: "[\\u0600-\\u06ff\\u0750-\\u077f]", options: [.regularExpression]) != nil {
            return "Arabic"
        } else if sampleText.range(of: "[\\u0590-\\u05ff]", options: [.regularExpression]) != nil {
            return "Hebrew"
        } else if sampleText.range(of: "[àáâãäåæçèéêëìíîïñòóôõöøùúûüý]", options: [.regularExpression, .caseInsensitive]) != nil {
            return "Romance Language (French/Spanish/Italian/etc.)"
        } else if sampleText.range(of: "[äöüß]", options: [.regularExpression, .caseInsensitive]) != nil {
            return "German"
        } else if sampleText.range(of: "[a-z]", options: [.regularExpression, .caseInsensitive]) != nil {
            return "Latin-based (English/etc.)"
        } else {
            return "Unknown/Mixed"
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
    
    // MARK: - Duplicate Detection and Removal
    
    private func removeDuplicateSegments(_ text: String) -> String {
        // Разделяем текст на абзацы, а не на предложения, для более консервативного подхода
        let paragraphs = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 } // Повышаем минимальную длину до 10 символов
        
        print("=== Duplicate Detection Started (Conservative Mode) ===")
        print("Original paragraphs count: \(paragraphs.count)")
        print("Original text length: \(text.count) characters")
        
        var uniqueParagraphs: [String] = []
        var seenParagraphs: [String] = []
        var duplicatesRemoved = 0
        
        for paragraph in paragraphs {
            // Normalize paragraph for comparison (remove extra spaces)
            let normalizedParagraph = paragraph
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Создаем ключ для сравнения (убираем case sensitivity только для сравнения)
            let comparisonKey = normalizedParagraph.lowercased()
            
            // Skip if we've seen this paragraph before (только точные совпадения)
            var isDuplicate = false
            
            // Проверяем только на точное совпадение для максимальной консервативности
            if seenParagraphs.contains(comparisonKey) {
                isDuplicate = true
                duplicatesRemoved += 1
                print("Exact duplicate found: '\(String(normalizedParagraph.prefix(50)))...'")
            }
            
            if !isDuplicate {
                uniqueParagraphs.append(normalizedParagraph)
                seenParagraphs.append(comparisonKey)
            }
        }
        
        // Соединяем абзацы обратно с переносами строк
        let result = uniqueParagraphs.joined(separator: "\n\n")
        
        print("Unique paragraphs count: \(uniqueParagraphs.count)")
        print("Duplicates removed: \(duplicatesRemoved)")
        print("Final text length: \(result.count) characters")
        if text.count > 0 {
            print("Compression ratio: \(String(format: "%.1f", Double(text.count) / Double(result.count)))x")
        }
        print("=== Duplicate Detection Completed ===")
        
        return result
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        // Используем комбинацию методов для более точного сравнения
        
        // 1. Точное совпадение
        if text1 == text2 {
            return 1.0
        }
        
        // 2. Если тексты слишком разные по длине, они не дубликаты
        let lengthRatio = Double(min(text1.count, text2.count)) / Double(max(text1.count, text2.count))
        if lengthRatio < 0.5 {
            return 0.0
        }
        
        // 3. Jaccard similarity по словам
        let words1 = Set(text1.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(text2.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        let jaccardSimilarity = union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
        
        // 4. Levenshtein distance для коротких строк (до 100 символов)
        let levenshteinSimilarity: Double
        if text1.count <= 100 && text2.count <= 100 {
            let distance = levenshteinDistance(text1, text2)
            let maxLength = max(text1.count, text2.count)
            levenshteinSimilarity = maxLength > 0 ? 1.0 - Double(distance) / Double(maxLength) : 1.0
        } else {
            levenshteinSimilarity = jaccardSimilarity // Fallback для длинных строк
        }
        
        // Возвращаем максимальное значение из двух методов
        return max(jaccardSimilarity, levenshteinSimilarity)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let len1 = str1.count
        let len2 = str2.count
        
        if len1 == 0 { return len2 }
        if len2 == 0 { return len1 }
        
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        
        var dp = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 {
            dp[i][0] = i
        }
        
        for j in 0...len2 {
            dp[0][j] = j
        }
        
        for i in 1...len1 {
            for j in 1...len2 {
                if str1Array[i - 1] == str2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }
        
        return dp[len1][len2]
    }
    
    // MARK: - Helper Functions
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Более точная оценка токенов для разных языков:
        // - Английский/латинские языки: ~4 символа на токен
        // - Кириллические языки (русский, украинский, болгарский): ~6-7 символов на токен
        // - Языки с иероглифами (китайский, японский): ~2-3 символа на токен
        // - Арабский/иврит: ~5-6 символов на токен
        // - Другие языки: среднее значение
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let avgCharactersPerToken: Double
        
        // Определяем тип языка по содержанию текста
        let sampleText = words.prefix(20).joined() // Увеличиваем выборку для лучшего определения
        
        // Проверяем кириллицу (русский, украинский, болгарский, сербский и т.д.)
        let cyrillicRange = sampleText.range(of: "[а-яёі]", options: [.regularExpression, .caseInsensitive])
        
        // Проверяем китайские/японские иероглифы
        let cjkRange = sampleText.range(of: "[\\u4e00-\\u9fff\\u3040-\\u309f\\u30a0-\\u30ff]", options: [.regularExpression])
        
        // Проверяем арабский текст
        let arabicRange = sampleText.range(of: "[\\u0600-\\u06ff\\u0750-\\u077f]", options: [.regularExpression])
        
        // Проверяем иврит
        let hebrewRange = sampleText.range(of: "[\\u0590-\\u05ff]", options: [.regularExpression])
        
        if cyrillicRange != nil {
            // Кириллические языки - менее эффективное токенизирование
            avgCharactersPerToken = 6.5
        } else if cjkRange != nil {
            // Китайский/японский - очень эффективное токенизирование
            avgCharactersPerToken = 2.5
        } else if arabicRange != nil || hebrewRange != nil {
            // Арабский/иврит - умеренно эффективное токенизирование
            avgCharactersPerToken = 5.5
        } else {
            // Английский и другие латинские языки
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
        
        switch currentModel {
        case .gemini2Flash:
            print("ℹ️  Google AI model with very large context window - excellent for multi-language processing")
        case .glm4Flash:
            print("⚠️  ZhipuAI model with smaller context window - optimal chunking applied for any language")
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
            // Заголовок движка с кнопками
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
                
                // Кнопка удаления
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete \(engine) transcription")
            }
            
            Divider()
            
            // Текст транскрипции (только для чтения)
            ScrollView {
                Text(transcription)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 400)
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
