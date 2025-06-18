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
    var onArchivedTextUpdate: ((String) -> Void)?
    
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var audioFormat: AVAudioFormat?
    private var isRecording: Bool = false
    private var transcriptionTimer: Timer?
    private let bufferLock = NSLock()
    
    // Accumulated transcription text (like Apple Speech Recognition)
    private var accumulatedText: String = ""
    private var archivedText: String = ""  // Store text when buffer resets
    private var lastProcessedBufferCount: Int = 0
    private var lastTranscriptionLength: Int = 0  // Track length of last transcription to detect new content
    private var lastContextTranscription: String = ""  // Store last context transcription for comparison
    
    // WhisperKit instance (will be uncommented when package is added)
    private var whisperKit: WhisperKit?
    
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
        archivedText = ""
        lastProcessedBufferCount = 0
        lastTranscriptionLength = 0
        lastContextTranscription = ""
        
        // Notify UI about cleared archived text
        self.onArchivedTextUpdate?("")
        
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
                let previousAccumulated = accumulatedText
                
                // Use the current transcription as the new accumulated text
                // WhisperKit's context windows provide the best available transcription
                accumulatedText = transcription
                
                // Only preserve previous text if current transcription is significantly shorter
                // and appears to be missing substantial content (likely a processing error)
                if !previousAccumulated.isEmpty &&
                   transcription.count < Int(Double(previousAccumulated.count) * 0.6) &&
                   previousAccumulated.count > 100 {
                    
                    // Check if current transcription seems to be a truncated version
                    let cleanPrevious = previousAccumulated.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanCurrent = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // If current is contained in previous and much shorter, keep previous
                    if cleanPrevious.contains(cleanCurrent) && cleanCurrent.count < Int(Double(cleanPrevious.count) * 0.8) {
                        accumulatedText = previousAccumulated
                        print("🎵 Keeping previous transcription (current seems truncated): \(previousAccumulated.count) chars vs \(transcription.count) chars")
                    } else {
                        // Buffer reset detected - archive the previous text
                        if !previousAccumulated.isEmpty && previousAccumulated.count > 50 {
                            if !archivedText.isEmpty {
                                archivedText += "\n\n--- Session Break ---\n\n" + previousAccumulated
                            } else {
                                archivedText = previousAccumulated
                            }
                            self.onArchivedTextUpdate?(archivedText)
                            print("🗄️ Archived previous text due to buffer reset: \(previousAccumulated.count) chars")
                        }
                        print("🎵 Using new transcription: \(accumulatedText)")
                    }
                } else {
                    print("🎵 Full context transcription: \(accumulatedText)")
                }
                
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
            let results = try await whisperKit.transcribe(audioArray: processedAudio)
            
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
}
