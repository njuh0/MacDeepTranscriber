import Foundation
import AVFoundation
import Combine
import WhisperKit // Uncomment when WhisperKit package is properly added
enum WhisperKitError: Error, LocalizedError {
    case modelNotLoaded
    case audioProcessingFailed
    case transcriptionFailed(String)
    case invalidAudioData
    case modelDownloadFailed
    case whisperKitInitFailed
    case genericError(String)
    
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please wait for model initialization."
        case .audioProcessingFailed:
            return "Failed to process audio data for transcription."
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error)"
        case .invalidAudioData:
            return "Invalid audio data format."
        case .modelDownloadFailed:
            return "Failed to download Whisper model."
        case .whisperKitInitFailed:
            return "Failed to initialize WhisperKit."
        case .genericError(let message):
            return message
        }
    }
}

@MainActor
class WhisperKitService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var isProcessing: Bool = false
    @Published var modelLoadingProgress: Double = 0.0
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadingStatus: String = "Initializing..."
    
    // Callbacks for external observation
    var onError: ((Error) -> Void)?
    var onAvailabilityChange: ((Bool) -> Void)?
    var onRecognitionResult: ((String) -> Void)?
    
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var audioFormat: AVAudioFormat?
    private var isRecording: Bool = false
    private var transcriptionTimer: Timer?
    private let bufferLock = NSLock()
    
    // Accumulated transcription text (like Apple Speech Recognition)
    private var accumulatedText: String = ""
    private var lastProcessedBufferCount: Int = 0
    private var lastTranscriptionLength: Int = 0  // Track length of last transcription to detect new content
    private var lastContextTranscription: String = ""  // Store last context transcription for comparison
    private var lastBufferResetTime: Date = Date()  // Время последнего сброса или очистки буфера
    
    @Published var transcriptionList: [TranscriptionEntry] = [] // Updated type
    
    // WhisperKit instance (will be uncommented when package is added)
    private var whisperKit: WhisperKit?
    // Removed historySeparator

    // Configuration
    private var modelName: String
    @Published var transcriptionInterval: TimeInterval
    @Published var maxBufferDuration: TimeInterval
    
    init(modelName: String = "base",
         transcriptionInterval: TimeInterval = 15.0,  // Увеличили до 15 секунд для лучшего качества
         maxBufferDuration: TimeInterval = 120.0) {   // Увеличили буфер до 2 минут
        self.modelName = modelName
        self.transcriptionInterval = transcriptionInterval
        self.maxBufferDuration = maxBufferDuration
        
        initializeWhisperKit()
        loadWhisperHistoryFromJSON() // Load history
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveWhisperHistoryToJSON() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("whisper_history.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self.transcriptionList)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("Successfully saved Whisper transcription history to \(fileURL.path)")
        } catch {
            print("Error saving Whisper transcription history to JSON: \(error.localizedDescription)")
        }
    }

    private func loadWhisperHistoryFromJSON() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("whisper_history.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Whisper history JSON file does not exist. Starting with empty history.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.transcriptionList = try decoder.decode([TranscriptionEntry].self, from: data)
            print("Successfully loaded Whisper transcription history from JSON. Count: \(self.transcriptionList.count)")
        } catch {
            print("Error loading Whisper transcription history from JSON: \(error.localizedDescription). Starting with empty history.")
            self.transcriptionList = [] // Ensure clean state on error
        }
    }
    
    // Methods to update configuration
    func updateTranscriptionInterval(_ interval: TimeInterval) {
        guard !isRecording else { return }
        self.transcriptionInterval = interval
        restartPeriodicTranscriptionIfNeeded()
    }
    
    func updateMaxBufferDuration(_ duration: TimeInterval) {
        guard !isRecording else { return }
        self.maxBufferDuration = duration
    }
    
    private func initializeWhisperKit() {
        Task {
            await loadWhisperModel()
        }
    }
    
    private func loadWhisperModel() async {
        print("🚀 Starting WhisperKit model loading for: \(modelName)")
        
        // Show where models will be stored
        let documentsPath = URL.documentsDirectory.path
        print("📁 Models will be stored in: \(documentsPath)")
        
        // Check if model directory already exists
        let modelPath = URL.documentsDirectory.appendingPathComponent("whisperkit-coreml").appendingPathComponent("openai_whisper-\(modelName)")
        let modelExists = FileManager.default.fileExists(atPath: modelPath.path)
        print("🔍 Model cache check: \(modelExists ? "EXISTS" : "NOT FOUND") at \(modelPath.path)")
        
        self.modelLoadingProgress = 0.0
        self.modelLoadingStatus = "Starting download..."
        
        // Real WhisperKit implementation:
        do {
            if modelExists {
                print("💾 Loading cached model: \(modelName)")
                self.modelLoadingStatus = "Loading cached model..."
            } else {
                print("� Downloading model: \(modelName) (this may take a while)")
                self.modelLoadingStatus = "Downloading model (first time)..."
            }
            
            // Try to initialize WhisperKit with local model first
            do {
                whisperKit = try await WhisperKit(
                    model: modelName,
                    downloadBase: URL.documentsDirectory,
                    prewarm: false,
                    load: true,
                    download: false  // Try without download first
                )
                print("✅ Local model loaded successfully from cache")
            } catch {
                print("⚠️ Local model not found, downloading: \(error)")
                // If local fails, try downloading
                whisperKit = try await WhisperKit(
                    model: modelName,
                    downloadBase: URL.documentsDirectory,
                    prewarm: false,
                    load: true,
                    download: true  // Download if local not available
                )
                print("✅ Model downloaded and loaded successfully")
                print("💾 Model cached for future use at: \(modelPath.path)")
            }
            
            self.modelLoadingProgress = 0.95
            
            // Small delay to show progress
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            self.isModelLoaded = true
            self.isAvailable = true
            self.modelLoadingProgress = 1.0
            self.onAvailabilityChange?(true)
            print("🎉 WhisperKit initialized successfully with model: \(self.modelName)")
            
        } catch {
            print("❌ Failed to initialize WhisperKit: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            self.onError?(WhisperKitError.whisperKitInitFailed)
            self.isAvailable = false
            self.modelLoadingProgress = 0.0
            self.onAvailabilityChange?(false)
        }
        
    }
    
    
    func startRecognition(audioFormat: AVAudioFormat) throws {
        guard isAvailable && isModelLoaded else {
            throw WhisperKitError.modelNotLoaded
        }
        
        self.audioFormat = audioFormat
        self.isRecording = true
        
        bufferLock.lock()
        audioBuffers.removeAll()
        bufferLock.unlock()
        
        // Clear accumulated text for new session
        accumulatedText = ""
        lastProcessedBufferCount = 0
        lastTranscriptionLength = 0
        lastContextTranscription = ""
        lastBufferResetTime = Date() // Инициализируем время сброса буфера
        
        // Start periodic transcription
        startPeriodicTranscription()
        
        print("WhisperKit recognition started")
    }
    
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording else { return }
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        audioBuffers.append(buffer)
        
        // Remove old buffers if we exceed max duration
        let totalDuration = audioBuffers.reduce(0.0) { total, buffer in
            return total + Double(buffer.frameLength) / buffer.format.sampleRate
        }
        
        var removedCount = 0
        while totalDuration > maxBufferDuration && !audioBuffers.isEmpty {
            audioBuffers.removeFirst()
            removedCount += 1
        }
        
        // Adjust the processed buffer count when we remove old buffers
        if removedCount > 0 {
            lastProcessedBufferCount = max(0, lastProcessedBufferCount - removedCount)
            // Обновляем время сброса буфера, так как старые данные были удалены
            lastBufferResetTime = Date()
            print("🧹 Buffer reset: removed \(removedCount) old buffers")
        }
    }
    
    func stopRecognition() {
        isRecording = false
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        
        bufferLock.lock()
        audioBuffers.removeAll()
        bufferLock.unlock()
        
        // Clear accumulated text when stopping
        accumulatedText = ""
        lastProcessedBufferCount = 0
        lastTranscriptionLength = 0
        lastContextTranscription = ""
        lastBufferResetTime = Date() // Сбрасываем время буфера при остановке
                
        print("WhisperKit recognition stopped")
    }
    
    private func startPeriodicTranscription() {
        // Cancel existing timer if any
        transcriptionTimer?.invalidate()
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: transcriptionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performTranscription()
            }
        }
    }
    
    // Restart timer with new interval if recording
    private func restartPeriodicTranscriptionIfNeeded() {
        if isRecording {
            startPeriodicTranscription()
        }
    }
    
    private func performTranscription() {
        guard isRecording && !audioBuffers.isEmpty else { return }
        
        bufferLock.lock()
        let allBuffers = Array(audioBuffers)
        bufferLock.unlock()
        
        // Используем перекрывающиеся сегменты для лучшего качества
        // Берем весь доступный контекст до максимального размера буфера
        let contextDuration: TimeInterval = maxBufferDuration
        let totalDuration = allBuffers.reduce(0.0) { total, buffer in
            return total + Double(buffer.frameLength) / buffer.format.sampleRate
        }
        
        let buffersToProcess: [AVAudioPCMBuffer]
        if totalDuration <= contextDuration {
            // Если общая длительность меньше контекста, используем все
            buffersToProcess = allBuffers
            print("🔄 Processing entire session: \(String(format: "%.1f", totalDuration))s (\(allBuffers.count) buffers)")
        } else {
            // Берем последние buffers в пределах maxBufferDuration для полного контекста
            var accumulatedDuration: TimeInterval = 0
            var startIndex = allBuffers.count
            
            for i in stride(from: allBuffers.count - 1, through: 0, by: -1) {
                let buffer = allBuffers[i]
                let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
                accumulatedDuration += bufferDuration
                startIndex = i
                
                if accumulatedDuration >= contextDuration {
                    break
                }
            }
            
            buffersToProcess = Array(allBuffers[startIndex...])
            print("🔄 Processing with full context: \(String(format: "%.1f", accumulatedDuration))s (\(buffersToProcess.count) buffers)")
        }
        
        Task {
            await transcribeWithContext(buffersToProcess)
        }
    }
    
    private func transcribeWithContext(_ buffers: [AVAudioPCMBuffer]) async {
        guard let audioFormat = audioFormat else { return }
        
        self.isProcessing = true
        
        do {
            // Combine all buffers into a single audio array
            let audioData = try combineBuffersToFloatArray(buffers, format: audioFormat)
            
            // Add audio diagnostics
            let duration = Double(audioData.count) / audioFormat.sampleRate
            let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))
            print("🎵 Context audio diagnostics: \(String(format: "%.2f", duration))s duration, RMS: \(String(format: "%.4f", rms))")
            
            // Skip transcription if audio is too short or quiet
            guard duration >= 0.5 && rms > 0.001 else {
                print("⚠️ Skipping transcription: audio too short or quiet")
                self.isProcessing = false
                return
            }
            
            // Transcribe using WhisperKit
            let transcription = try await transcribeAudioData(audioData)
            
            // Update UI on main thread - use smart transcription replacement
            self.isProcessing = false
            if !transcription.isEmpty {
                // Use the current transcription as the new accumulated text
                // WhisperKit's context windows provide the best available transcription
                accumulatedText = transcription
                
                // Get clean versions of transcriptions for comparison
                let cleanTranscription = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                let timeSinceBufferReset = Date().timeIntervalSince(lastBufferResetTime)
                // preventing random sudden changes as much as possible. Saving model only at the last moment
                let canAddTranscription = timeSinceBufferReset > maxBufferDuration * 0.90
                print("Buffer reset time: \(String(format: "%.1f", timeSinceBufferReset))s, max buffer duration: \(String(format: "%.1f", maxBufferDuration))s")
       
                if canAddTranscription {
                    if !self.transcriptionList.isEmpty {
                        let lastIndex = self.transcriptionList.count - 1
                        // Assuming lastTranscription here is used for its textual content for similarity
                        let lastTranscriptionText = self.transcriptionList[lastIndex].transcription 
                        let cleanLastTranscription = lastTranscriptionText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let similarity = calculateTextSimilarity(cleanTranscription, cleanLastTranscription)
                        print("🔍 Similarity: \(String(format: "%.2f", similarity))")
                        if similarity > 0.5 {
                            let updatedEntry = TranscriptionEntry(date: Date(), transcription: transcription)
                            self.transcriptionList[lastIndex] = updatedEntry
                            self.saveWhisperHistoryToJSON()
                            print("🔄 Updated last transcription entry with more complete version: \(transcription.count) chars")
                        } else {
                            let newEntry = TranscriptionEntry(date: Date(), transcription: accumulatedText) // accumulatedText contains the full new transcription
                            self.transcriptionList.append(newEntry)
                            self.saveWhisperHistoryToJSON()
                        }
                    } else {
                        // Список пуст, просто добавляем первую запись
                        let newEntry = TranscriptionEntry(date: Date(), transcription: accumulatedText)
                        self.transcriptionList.append(newEntry)
                        self.saveWhisperHistoryToJSON()
                        print("➕ Added first transcription entry to list: \(accumulatedText.count) chars")
                    }
                }
                print("🎵 Current transcription (accumulatedText): \(accumulatedText.count) chars")
                self.onRecognitionResult?(accumulatedText)
            }
            
        } catch {
            self.isProcessing = false
            self.onError?(error)
        }
    }
    
    
    private func transcribeBuffers(_ buffers: [AVAudioPCMBuffer]) async {
        guard let audioFormat = audioFormat else { return }
        
        self.isProcessing = true
        
        do {
            // Combine all buffers into a single audio array
            let audioData = try combineBuffersToFloatArray(buffers, format: audioFormat)
            
            // Add audio diagnostics
            let duration = Double(audioData.count) / audioFormat.sampleRate
            let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))
            print("🔍 Audio diagnostics: \(String(format: "%.2f", duration))s duration, RMS: \(String(format: "%.4f", rms))")
            
            // Skip transcription if audio is too quiet or too short
            guard duration >= 0.5 && rms > 0.001 else {
                print("⚠️ Skipping transcription: audio too short or quiet")
                self.isProcessing = false
                return
            }
            
            // Transcribe using WhisperKit
            let transcription = try await transcribeAudioData(audioData)
            
            // Update UI on main thread
            self.isProcessing = false
            if !transcription.isEmpty {
                // Добавляем новый текст к существующему (накопительная транскрипция)
                if !accumulatedText.isEmpty {
                    accumulatedText += " " + transcription
                } else {
                    accumulatedText = transcription
                }
                
                // Send the accumulated transcription
                self.onRecognitionResult?(accumulatedText)
                print("WhisperKit added text: \(transcription)")
                print("WhisperKit total text: \(accumulatedText)")
            }
            
        } catch {
            self.isProcessing = false
            self.onError?(error)
        }
    }
    
    private func combineBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) throws -> [Float] {
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        var audioData: [Float] = []
        audioData.reserveCapacity(totalFrames)
        
        for buffer in buffers {
            let frameLength = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData?[0] else {
                throw WhisperKitError.invalidAudioData
            }
            
            for i in 0..<frameLength {
                audioData.append(channelData[i])
            }
        }
        
        // Normalize audio data to prevent clipping and improve recognition
        let normalizedAudio = normalizeAudio(audioData)
        
        print("🎵 Combined \(buffers.count) buffers into \(normalizedAudio.count) samples")
        return normalizedAudio
    }
    
    private func normalizeAudio(_ audioData: [Float]) -> [Float] {
        guard !audioData.isEmpty else { return audioData }
        
        // Find the maximum absolute value
        let maxValue = audioData.map { abs($0) }.max() ?? 1.0
        
        // Avoid division by zero and don't normalize if already quiet
        guard maxValue > 0.001 else { return audioData }
        
        // Normalize to 0.8 to prevent clipping
        let normalizationFactor = 0.8 / maxValue
        return audioData.map { $0 * normalizationFactor }
    }
    
    private func transcribeAudioData(_ audioData: [Float]) async throws -> String {
        // Real WhisperKit implementation:
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.modelNotLoaded
        }
        
        do {
            // WhisperKit expects 16kHz sample rate
            let targetSampleRate: Float = 16000.0
            let currentSampleRate = Float(audioFormat?.sampleRate ?? 44100.0)
            
            // Resample audio if needed
            let processedAudio: [Float]
            if currentSampleRate != targetSampleRate {
                processedAudio = resampleAudio(audioData, from: currentSampleRate, to: targetSampleRate)
                print("🔄 Resampled audio from \(currentSampleRate)Hz to \(targetSampleRate)Hz")
            } else {
                processedAudio = audioData
            }
            
            // Ensure minimum audio length (WhisperKit needs at least ~1 second)
            guard processedAudio.count >= Int(targetSampleRate * 0.5) else {
                print("⚠️ Audio too short: \(processedAudio.count) samples")
                return ""
            }
            
            print("🎵 Processing audio: \(processedAudio.count) samples at \(targetSampleRate)Hz")
            
            // Transcribe using WhisperKit with audioArray method
            let results = try await whisperKit.transcribe(audioArray: processedAudio, decodeOptions: DecodingOptions(task: .transcribe, language: "en"))
            
            // Extract text from first result (WhisperKit returns [TranscriptionResult])
            let transcription = results.first?.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            print("✅ WhisperKit transcription: \(transcription)")
            return transcription
            
        } catch {
            print("❌ WhisperKit transcription error: \(error)")
            throw WhisperKitError.transcriptionFailed(error.localizedDescription)
        }
        
    }
    
    private func resampleAudio(_ audioData: [Float], from sourceSampleRate: Float, to targetSampleRate: Float) -> [Float] {
        let ratio = sourceSampleRate / targetSampleRate
        let targetLength = Int(Float(audioData.count) / ratio)
        var resampledData: [Float] = []
        resampledData.reserveCapacity(targetLength)
        
        for i in 0..<targetLength {
            let sourceIndex = Int(Float(i) * ratio)
            if sourceIndex < audioData.count {
                resampledData.append(audioData[sourceIndex])
            }
        }
        
        return resampledData
    }
    
    
    
}

// MARK: - WhisperKit Integration Helper
extension WhisperKitService {
    
    /// Returns available Whisper models
    static func availableModels() -> [String] {
        return [
            "tiny",
            "base",
            "small",
            "medium",
            "large-v2",
            "large-v3"
        ]
    }
    
    /// Returns model size information
    static func modelInfo(for modelName: String) -> (size: String, description: String) {
        switch modelName {
        case "tiny":
            return ("150-200 MB", "Fastest, least accurate")
        case "base":
            return ("290-350 MB", "Good balance of speed and accuracy")
        case "small":
            return ("970 MB - 1.2 GB", "Better accuracy, slower")
        case "medium":
            return ("2.3 - 2.8 GB", "High accuracy, much slower")
        case "large-v2", "large-v3":
            return ("4.5 - 5.5 GB", "Best accuracy, very slow")
        default:
            return ("Unknown", "Custom model")
        }
    }
    
    /// Switch to a different model
    func switchModel(to newModelName: String) {
        guard !isRecording else {
            onError?(WhisperKitError.genericError("Cannot switch models while recording"))
            return
        }
        
        // Update the model name
        self.modelName = newModelName
        
        // Reset state
        self.whisperKit = nil
        self.isModelLoaded = false
        self.isAvailable = false
        self.modelLoadingProgress = 0.0
        self.modelLoadingStatus = "Switching to \(newModelName)..."
        
        // Keep accumulated text when switching models
        
        // Load new model
        Task {
            await loadWhisperModel()
        }
    }
    
    // Функция для расчета схожести двух текстов
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        // Если один из текстов пустой, возвращаем 0
        if text1.isEmpty || text2.isEmpty {
            return 0.0
        }
        
        // Если тексты идентичны, возвращаем 1
        if text1 == text2 {
            return 1.0
        }
        
        // Простой алгоритм - проверяем содержание одного текста в другом
        if text1.count > text2.count {
            if text1.contains(text2) {
                return Double(text2.count) / Double(text1.count)
            }
        } else {
            if text2.contains(text1) {
                return Double(text1.count) / Double(text2.count)
            }
        }
        
        // Более продвинутая проверка - считаем общие слова
        let words1 = Set(text1.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(text2.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        if words1.isEmpty || words2.isEmpty {
            return 0.1
        }
        
        let commonWords = words1.intersection(words2)
        let similarity = Double(commonWords.count) / Double(max(words1.count, words2.count))
        
        return similarity
    }
}

// MARK: - AVAudioEngine Error Handling
extension AVAudioEngine {
    /// Safely starts the audio engine with proper error handling for HAL errors
    func safeStart() throws {
        do {
            try self.start()
        } catch {
            // Handle specific CoreAudio errors
            let nsError = error as NSError
            if nsError.domain == NSOSStatusErrorDomain {
                // Common CoreAudio error codes
                switch nsError.code {
                case -10877: // kAudioHardwareNotRunningError
                    print("🔊 Audio Hardware Error: Device not available or running (-10877)")
                    throw AppError.deviceNotAvailable
                    
                case -10875: // kAudioHardwareUnspecifiedError
                    print("🔊 Audio Hardware Error: Unspecified hardware error (-10875)")
                    throw AppError.coreAudioError(nsError.code, "Hardware error")
                    
                case -10851: // kAudioHardwareUnsupportedOperationError
                    print("🔊 Audio Hardware Error: Unsupported operation (-10851)")
                    throw AppError.coreAudioError(nsError.code, "Unsupported operation")
                    
                default:
                    print("🔊 Audio Hardware Error: \(nsError.code)")
                    throw AppError.coreAudioError(nsError.code, "Unknown audio error")
                }
            } else {
                throw error
            }
        }
    }
}

// Add comprehensive CoreAudio error code mapping
extension AppError {
    static func mapCoreAudioErrorCode(_ code: Int) -> String {
        switch code {
        case -10877:
            return "Audio device not available or not running. Check that your audio device is properly connected and that no other app is using it exclusively."
        case -10875:
            return "Unspecified audio hardware error. Try restarting your Mac or reconnecting your audio devices."
        case -10851:
            return "Unsupported audio operation. Your current audio configuration may not be compatible."
        case -10879:
            return "Audio device not found. Check your audio hardware connections."
        case -10878:
            return "Audio device is busy. Another application may be using the audio device exclusively."
        case -10876:
            return "Audio hardware initialization failed."
        case -10868:
            return "Audio hardware stream format error."
        case -10867:
            return "Audio hardware is in use by another application."
        case -10866:
            return "Audio hardware IO operation aborted."
        default:
            return "CoreAudio error \(code). Check your audio hardware and settings."
        }
    }
}
