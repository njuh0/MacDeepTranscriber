import Foundation
import AVFoundation
import Combine
import Speech

@MainActor
class AudioCaptureService: ObservableObject {
    @Published var statusMessage: String = "Press 'Start' to begin audio capture..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?
    @Published var recognizedText: String = ""
    @Published var isSpeechRecognitionAvailable: Bool = false
    @Published var isMicrophoneAccessGranted: Bool = false
    @Published var isWhisperKitProcessing: Bool = false
    @Published var modelLoadingProgress: Double = 0.0
    @Published var isModelLoaded: Bool = false
    @Published var selectedWhisperModel: String = "base"
    @Published var modelLoadingStatus: String = "Ready"
    @Published var transcriptionList: [TranscriptionEntry] = []
    
    // Speech engine selection
    @Published var selectedSpeechEngines: Set<SpeechEngineType> = [.appleSpeech]
    @Published var appleSpeechText: String = ""
    @Published var appleSpeechHistory: [String] = []
    
    // No need for combined persistence service anymore
    
    // Old property kept for compatibility during refactoring
    var useAppleSpeechInParallel: Bool {
        get { selectedSpeechEngines.contains(.appleSpeech) }
        set {
            if newValue {
                selectedSpeechEngines.insert(.appleSpeech)
            } else {
                selectedSpeechEngines.remove(.appleSpeech)
            }
        }
    }
    
    // WhisperKit Configuration
    @Published var whisperTranscriptionInterval: TimeInterval = 15.0
    @Published var whisperMaxBufferDuration: TimeInterval = 120.0
    @Published var whisperSelectedLanguage: String = "en" // ISO 639-1 код для WhisperKit
    @Published var whisperTaskType: WhisperTaskType = .transcribe // transcribe или translate
    
    // Apple Speech Configuration
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")

    private var audioEngine: AVAudioEngine?
    private var whisperKitService: WhisperKitService
    // Expose the service so ContentView can access locale info
    let speechRecognizerService: SpeechRecognizerService
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize services
        whisperKitService = WhisperKitService()
        speechRecognizerService = SpeechRecognizerService()
        
        // Request microphone access early
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isMicrophoneAccessGranted = granted
                if granted {
                    print("Microphone access granted.")
                    self?.errorMessage = nil
                } else {
                    print("Microphone access denied.")
                }
            }
        }
        
        // Set up callbacks after all properties are initialized
        setupCallbacks()
        
        // Individual services load their own histories automatically
        print("ℹ️ AudioCaptureService initialized - individual engines manage their own JSON files")
    }
    
    private func setupCallbacks() {
        setupWhisperKitCallbacks()
        
        // Set initial availability based on WhisperKit
        updateAvailability()
        
        // Subscribe to WhisperKit processing state
        whisperKitService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWhisperKitProcessing)
            
        whisperKitService.$modelLoadingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$modelLoadingProgress)
            
        whisperKitService.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoaded)
            
        whisperKitService.$modelLoadingStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$modelLoadingStatus)
            
        // Set up Apple Speech callbacks
        speechRecognizerService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                // Always store in appleSpeechText
                self?.appleSpeechText = text
            }
            .store(in: &cancellables)
            
        // Subscribe to WhisperKit transcription history (permanent storage)
        whisperKitService.$transcriptionList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (permanentHistory: [TranscriptionEntry]) in
                self?.updateWhisperKitDisplayList()
            }
            .store(in: &cancellables)
            
        // Subscribe to WhisperKit session transcriptions (temporary during recording)
        whisperKitService.$sessionTranscriptions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (sessionHistory: [TranscriptionEntry]) in
                self?.updateWhisperKitDisplayList()
            }
            .store(in: &cancellables)
            
        speechRecognizerService.$sessionTranscriptions // Apple Speech session history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (sessionHistory: [TranscriptionEntry]) in
                self?.updateAppleSpeechDisplayList()
                // Also update the combined transcription list and save to JSON
                self?.updateWhisperKitDisplayList()
            }
            .store(in: &cancellables)
            
        speechRecognizerService.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                if self?.useAppleSpeechInParallel == true {
                    // Only show Apple Speech errors if we're using it
                    self?.errorMessage = "Apple Speech: \(error)"
                }
            }
            .store(in: &cancellables)
            
        // Sync initial model selection and configuration
        Task { @MainActor [self] in
            if selectedWhisperModel != "base" {
                switchWhisperModel(to: selectedWhisperModel)
            }
            // Sync initial configuration values
            updateWhisperTranscriptionInterval(whisperTranscriptionInterval)
            updateWhisperMaxBufferDuration(whisperMaxBufferDuration)
            updateWhisperLanguage(whisperSelectedLanguage)
            updateWhisperTaskType(whisperTaskType)
            
            // Initialize display lists
            updateWhisperKitDisplayList()
            updateAppleSpeechDisplayList()
        }
    }
    
    private func setupWhisperKitCallbacks() {
        whisperKitService.onError = { [weak self] error in
            DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    print("WhisperKitService Error: \(error.localizedDescription)")
                
            }
        }
        whisperKitService.onAvailabilityChange = { [weak self] available in
            DispatchQueue.main.async {
                    self?.isSpeechRecognitionAvailable = available
                    print("WhisperKit availability changed: \(available)")
                
            }
        }
        whisperKitService.onRecognitionResult = { [weak self] text in
            DispatchQueue.main.async {
                    self?.recognizedText = text
                
            }
        }
    }
    
    // We no longer need this method since we're using WhisperKit as the primary engine
    // and Apple Speech is only used in parallel when enabled
    
    private func updateAvailability() {
        // Since WhisperKit is our primary engine now
        isSpeechRecognitionAvailable = whisperKitService.isAvailable
    }
    
    // Method to update selected speech engines
    func updateSelectedSpeechEngines(_ engines: Set<SpeechEngineType>) {
        let previousEngines = selectedSpeechEngines
        selectedSpeechEngines = engines
        
        // Handle Apple Speech changes if we're already capturing
        if isCapturing {
            let wasAppleSpeechEnabled = previousEngines.contains(.appleSpeech)
            let isAppleSpeechEnabled = engines.contains(.appleSpeech)
            
            // Start Apple Speech if newly enabled
            if !wasAppleSpeechEnabled && isAppleSpeechEnabled {
                startAppleSpeech()
            }
            // Stop Apple Speech if newly disabled
            else if wasAppleSpeechEnabled && !isAppleSpeechEnabled {
                stopAppleSpeech()
            }
        }
    }
    
    // For backward compatibility
    func toggleAppleSpeechParallel(_ enabled: Bool) {
        var engines = selectedSpeechEngines
        if enabled {
            engines.insert(.appleSpeech)
        } else {
            engines.remove(.appleSpeech)
        }
        updateSelectedSpeechEngines(engines)
    }
    

    func switchWhisperModel(to modelName: String) {
        guard !isCapturing else {
            errorMessage = "Cannot switch models while capturing. Stop capture first."
            return
        }
        
        selectedWhisperModel = modelName
        whisperKitService.switchModel(to: modelName)
        statusMessage = "Switching to \(modelName) model..."
    }
    
    func updateWhisperTranscriptionInterval(_ interval: TimeInterval) {
        guard !isCapturing else {
            errorMessage = "Cannot change settings while capturing. Stop capture first."
            return
        }
        
        whisperTranscriptionInterval = interval
        whisperKitService.updateTranscriptionInterval(interval)
        statusMessage = "Updated transcription interval to \(String(format: "%.1f", interval)) seconds."
    }
    
    func updateWhisperMaxBufferDuration(_ duration: TimeInterval) {
        guard !isCapturing else {
            errorMessage = "Cannot change settings while capturing. Stop capture first."
            return
        }
        
        whisperMaxBufferDuration = duration
        whisperKitService.updateMaxBufferDuration(duration)
        statusMessage = "Updated max buffer duration to \(String(format: "%.0f", duration)) seconds."
    }
    
    func clearRecognizedText() {
        recognizedText = ""
        appleSpeechText = ""
        statusMessage = "Transcription text cleared."
        
        // Опционально очищаем также историю Apple Speech
        if useAppleSpeechInParallel {
            speechRecognizerService.clearRecognizedText(clearHistory: false)
        }
    }
    
    // Метод для очистки истории Apple Speech
    func clearAppleSpeechHistory() {
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    // Method to clear duplicates in Apple Speech history
    func cleanupAppleSpeechDuplicates() {
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    // Method to clear transcription history
    func clearTranscriptionHistory() {
        transcriptionList = []
        // Clear individual engine histories - they handle their own JSON files
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    
    func clearTranscriptionList() {
        transcriptionList = []
        // Clear individual engine histories - they handle their own JSON files  
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }

    func startCapture() {
        guard !isCapturing else { return }
        
        if audioEngine != nil {
            stopCapture()
        }

        do {
            // Verify at least one engine is selected
            if selectedSpeechEngines.isEmpty {
                throw AppError.noSpeechEngineSelected
            }
            
            // Start a new session (clears previous session data)
            startNewSession()
            
            // Configure audio engine for all engines to use
            try configureAudioEngine()
            let recordingFormat = audioEngine!.inputNode.outputFormat(forBus: 0)
            
            // Start selected engines
            if selectedSpeechEngines.contains(.whisperKit) {
                try whisperKitService.startRecognition(audioFormat: recordingFormat)
                statusMessage = "WhisperKit active. Processing..."
            }
            
            if selectedSpeechEngines.contains(.appleSpeech) {
                try startAppleSpeechCapture()
            }
            
            isCapturing = true
        } catch {
            isCapturing = false
            stopCapture()
            
            // Handle specific errors with user-friendly messages
            if let appError = error as? AppError {
                errorMessage = appError.errorDescription
                
                switch appError {
                case .deviceNotAvailable:
                    statusMessage = "⚠️ Audio device error: Please check your audio input settings"
                case .microphonePermissionDenied:
                    statusMessage = "⚠️ Microphone access denied"
                case .coreAudioError(let code, _):
                    statusMessage = "⚠️ CoreAudio error (\(code)). Try restarting your app"
                case .noSpeechEngineSelected:
                    statusMessage = "⚠️ Please select at least one speech engine"
                default:
                    statusMessage = "⚠️ Failed to start audio capture"
                }
            } else if let whisperError = error as? WhisperKitError {
                errorMessage = whisperError.localizedDescription
                statusMessage = "⚠️ WhisperKit error"
            } else {
                errorMessage = error.localizedDescription
                statusMessage = "⚠️ Failed to start audio capture"
            }
            
            print("Error starting capture: \(error.localizedDescription)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }

        print("🛑 AudioCaptureService: Starting stopCapture process...")
        
        // Stop active engines first to ensure final transcriptions are captured
        if selectedSpeechEngines.contains(.whisperKit) {
            print("🛑 Stopping WhisperKit recognition...")
            whisperKitService.stopRecognition()
            print("✅ WhisperKit stopped. Session count: \(whisperKitService.sessionTranscriptions.count)")
        }
        
        if selectedSpeechEngines.contains(.appleSpeech) {
            print("🛑 Stopping Apple Speech recognition...")
            speechRecognizerService.stopRecognition()
            print("✅ Apple Speech stopped. Session count: \(speechRecognizerService.sessionTranscriptions.count)")
        }

        // Small delay to ensure any final async operations complete
        Task {
            // Wait a brief moment for any final transcriptions to be processed
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                // Now save session transcriptions to permanent storage after stopping
                print("💾 Saving session transcriptions to permanent storage...")
                self.saveSessionToPermanentStorage()
                
                // Stop audio engine in any case
                if let engine = self.audioEngine {
                    engine.stop()
                    if engine.inputNode.numberOfInputs > 0 {
                        engine.inputNode.removeTap(onBus: 0)
                    }
                }
                self.audioEngine = nil

                self.isCapturing = false
                print("✅ Capture stopped and session saved.")
            }
        }
    }
    
    // Helper methods for Apple Speech
    private func startAppleSpeech() {
        Task {
            do {
                try await speechRecognizerService.startRecognition()
            } catch {
                print("Error starting Apple Speech: \(error.localizedDescription)")
                if useAppleSpeechInParallel {
                    errorMessage = "Apple Speech error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func stopAppleSpeech() {
        speechRecognizerService.stopRecognition()
    }
    
    // MARK: - Speech Engine Specific Methods
    
    private func startWhisperKitCapture() throws {
        try configureAudioEngine()
        
        let recordingFormat = audioEngine!.inputNode.outputFormat(forBus: 0)
        
        // Start recognition with WhisperKit
        try whisperKitService.startRecognition(audioFormat: recordingFormat)
        statusMessage = "Audio capture active with WhisperKit. Processing..."
    }
    
    private func startAppleSpeechCapture() throws {
        // Start Apple Speech recognition using Task to handle async
        Task {
            do {
                try await speechRecognizerService.startRecognition()
                await MainActor.run {
                    statusMessage = "Audio capture active with Apple Speech. Processing..."
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to start Apple Speech: \(error.localizedDescription)"
                    self.isCapturing = false
                }
            }
        }
    }

    private func configureAudioEngine() throws {
        print("Attempting to configure AVAudioEngine...")
        audioEngine = AVAudioEngine()
        print("AVAudioEngine initialized.")

        let engine = audioEngine!

        let inputNode = engine.inputNode
        print("InputNode obtained. Number of inputs: \(inputNode.numberOfInputs)")
        
        if inputNode.numberOfInputs == 0 {
            print("Error: InputNode has no inputs. BlackHole might not be selected as system input.")
            throw AppError.deviceNotAvailable
        }

        let recordingFormat: AVAudioFormat
        do {
            recordingFormat = inputNode.outputFormat(forBus: 0)
            print("Recording format obtained: Channels=\(recordingFormat.channelCount), SampleRate=\(recordingFormat.sampleRate)")
        }

        // Install a tap on the input node and pass buffers to the selected engine
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Process buffer with WhisperKit
            Task { @MainActor in
                self.whisperKitService.appendAudioBuffer(buffer)
            }
        }
        print("InputNode tap installed on bus 0.")

        print("Preparing AVAudioEngine...")
        engine.prepare()
        print("AVAudioEngine prepared.")
        
        do {
            print("Starting AVAudioEngine...")
            try engine.safeStart() // Use our custom safe start method
            print("AVAudioEngine started successfully.")
        } catch {
            let nsError = error as NSError
            
            // Handle permission errors
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 13 {
                print("Error starting AVAudioEngine: Permission denied (Microphone access).")
                throw AppError.microphonePermissionDenied
            } 
            // Handle CoreAudio specific errors
            else if nsError.domain == NSOSStatusErrorDomain {
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
                    print("🔊 CoreAudio Error: \(nsError.code)")
                    throw AppError.coreAudioError(nsError.code, "Unknown audio error")
                }
            } else {
                print("Fatal Error starting AVAudioEngine: \(nsError.localizedDescription) (Domain: \(nsError.domain), Code: \(nsError.code))")
                throw AppError.engineStartError("Audio engine failed to start: \(nsError.localizedDescription)")
            }
        }
    }
    
    // Apple Speech methods
    func getSupportedLocalesWithNames() -> [(Locale, String)] {
        return speechRecognizerService.getSupportedLocalesWithNames()
    }
    
    func changeLocale(to locale: Locale) {
        if isCapturing {
            stopCapture()
        }
        selectedLocale = locale
        speechRecognizerService.changeLocale(to: locale)
        
        // Синхронизация языка с WhisperKit
        syncLanguageToWhisperKit(from: locale)
    }
    
    // Синхронизация языка между Apple Speech и WhisperKit
    private func syncLanguageToWhisperKit(from locale: Locale) {
        let whisperLanguage = appleLocaleToWhisperLanguage(locale)
        if whisperSelectedLanguage != whisperLanguage {
            whisperSelectedLanguage = whisperLanguage
            whisperKitService.updateLanguage(whisperLanguage)
        }
    }
    
    private func syncLanguageToAppleSpeech(from whisperLanguage: String) {
        let appleLocale = whisperLanguageToAppleLocale(whisperLanguage)
        if selectedLocale.identifier != appleLocale.identifier {
            selectedLocale = appleLocale
            speechRecognizerService.changeLocale(to: appleLocale)
        }
    }
    
    // Метод для обновления языка WhisperKit
    func updateWhisperLanguage(_ language: String) {
        whisperSelectedLanguage = language
        whisperKitService.updateLanguage(language)
        
        // Синхронизируем с Apple Speech
        syncLanguageToAppleSpeech(from: language)
    }
    
    // Метод для обновления типа задачи WhisperKit
    func updateWhisperTaskType(_ taskType: WhisperTaskType) {
        whisperTaskType = taskType
        whisperKitService.updateTaskType(taskType)
    }
    
    // Поддерживаемые языки для WhisperKit (ISO 639-1)
    func getSupportedWhisperLanguages() -> [(String, String)] {
        return [
            ("en", "English"),
            ("ru", "Русский"),
            ("es", "Español"),
            ("fr", "Français"),
            ("de", "Deutsch"),
            ("it", "Italiano"),
            ("pt", "Português"),
            ("zh", "中文"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("ar", "العربية"),
            ("hi", "हिन्दी"),
            ("tr", "Türkçe"),
            ("pl", "Polski"),
            ("nl", "Nederlands"),
            ("sv", "Svenska"),
            ("da", "Dansk"),
            ("no", "Norsk"),
            ("fi", "Suomi"),
            ("uk", "Українська"),
            ("cs", "Čeština"),
            ("sk", "Slovenčina"),
            ("hu", "Magyar"),
            ("ro", "Română"),
            ("bg", "Български"),
            ("hr", "Hrvatski"),
            ("sr", "Српски"),
            ("sl", "Slovenščina"),
            ("et", "Eesti"),
            ("lv", "Latviešu"),
            ("lt", "Lietuvių"),
            ("mt", "Malti"),
            ("ga", "Gaeilge"),
            ("cy", "Cymraeg"),
            ("is", "Íslenska"),
            ("mk", "Македонски"),
            ("sq", "Shqip"),
            ("eu", "Euskera"),
            ("ca", "Català"),
            ("gl", "Galego")
        ]
    }
    
    // Конвертация локали Apple Speech в язык WhisperKit
    private func appleLocaleToWhisperLanguage(_ locale: Locale) -> String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        // Маппинг основных языков
        switch languageCode {
        case "zh": 
            // Для китайского определяем упрощенный или традиционный
            if locale.identifier.contains("CN") || locale.identifier.contains("Hans") {
                return "zh"
            } else {
                return "zh" // WhisperKit использует "zh" для китайского
            }
        default:
            return languageCode
        }
    }
    
    // Конвертация языка WhisperKit в локаль Apple Speech
    private func whisperLanguageToAppleLocale(_ language: String) -> Locale {
        // Маппинг основных языков обратно в локали Apple
        switch language {
        case "en": return Locale(identifier: "en-US")
        case "ru": return Locale(identifier: "ru-RU")
        case "es": return Locale(identifier: "es-ES")
        case "fr": return Locale(identifier: "fr-FR")
        case "de": return Locale(identifier: "de-DE")
        case "it": return Locale(identifier: "it-IT")
        case "pt": return Locale(identifier: "pt-BR")
        case "zh": return Locale(identifier: "zh-CN")
        case "ja": return Locale(identifier: "ja-JP")
        case "ko": return Locale(identifier: "ko-KR")
        case "ar": return Locale(identifier: "ar-SA")
        case "hi": return Locale(identifier: "hi-IN")
        case "tr": return Locale(identifier: "tr-TR")
        case "pl": return Locale(identifier: "pl-PL")
        case "nl": return Locale(identifier: "nl-NL")
        case "sv": return Locale(identifier: "sv-SE")
        case "da": return Locale(identifier: "da-DK")
        case "no": return Locale(identifier: "no-NO")
        case "fi": return Locale(identifier: "fi-FI")
        case "uk": return Locale(identifier: "uk-UA")
        case "cs": return Locale(identifier: "cs-CZ")
        case "sk": return Locale(identifier: "sk-SK")
        case "hu": return Locale(identifier: "hu-HU")
        case "ro": return Locale(identifier: "ro-RO")
        case "bg": return Locale(identifier: "bg-BG")
        case "hr": return Locale(identifier: "hr-HR")
        case "sr": return Locale(identifier: "sr-RS")
        case "sl": return Locale(identifier: "sl-SI")
        case "et": return Locale(identifier: "et-EE")
        case "lv": return Locale(identifier: "lv-LV")
        case "lt": return Locale(identifier: "lt-LT")
        case "mt": return Locale(identifier: "mt-MT")
        case "ga": return Locale(identifier: "ga-IE")
        case "cy": return Locale(identifier: "cy-GB")
        case "is": return Locale(identifier: "is-IS")
        default: return Locale(identifier: "en-US")
        }
    }
    
    // MARK: - Session Management
    
    func saveSessionToPermanentStorage() {
        print("💾 AudioCaptureService: Starting saveSessionToPermanentStorage...")
        
        // Save WhisperKit session transcriptions
        if selectedSpeechEngines.contains(.whisperKit) {
            let sessionCount = whisperKitService.sessionTranscriptions.count
            print("💾 Saving \(sessionCount) WhisperKit session transcriptions...")
            whisperKitService.saveSessionToPermanentStorage()
        }
        
        // Save Apple Speech session transcriptions
        if selectedSpeechEngines.contains(.appleSpeech) {
            let sessionCount = speechRecognizerService.sessionTranscriptions.count
            print("💾 Saving \(sessionCount) Apple Speech session transcriptions...")
            speechRecognizerService.saveSessionTranscriptionsToPermanentStorage()
        }
        
        // Update the combined transcription list (individual services save their own JSON)
        updateWhisperKitDisplayList()
        
        print("✅ Session transcriptions saved to permanent storage and JSON updated")
        statusMessage = "Session transcriptions saved to storage"
    }
    
    func startNewSession() {
        // Clear session data for WhisperKit
        if selectedSpeechEngines.contains(.whisperKit) {
            whisperKitService.clearSession()
        }
        
        // Clear session data for Apple Speech
        if selectedSpeechEngines.contains(.appleSpeech) {
            speechRecognizerService.startNewRecordingSession()
        }
        
        // Clear current text
        recognizedText = ""
        appleSpeechText = ""
        errorMessage = nil
        
        print("Started new recording session")
        statusMessage = "New session started"
    }
    
    // Helper method to update WhisperKit display list (combines permanent + session)
    private func updateWhisperKitDisplayList() {
        updateCombinedTranscriptionList()
    }
    
    // Helper method to update the combined transcription list from all active speech engines
    private func updateCombinedTranscriptionList() {
        var combinedList: [TranscriptionEntry] = []
        
        // Add WhisperKit transcriptions (permanent + session)
        if selectedSpeechEngines.contains(.whisperKit) {
            let permanentList = whisperKitService.transcriptionList
            let sessionList = whisperKitService.sessionTranscriptions
            combinedList.append(contentsOf: permanentList + sessionList)
        }
        
        // Add Apple Speech transcriptions (permanent + session)  
        if selectedSpeechEngines.contains(.appleSpeech) {
            // We can only access session transcriptions, permanent ones are handled by the service itself
            let sessionList = speechRecognizerService.sessionTranscriptions
            combinedList.append(contentsOf: sessionList)
        }
        
        // Sort by date to maintain chronological order
        combinedList.sort { entry1, entry2 in
            // Parse the ISO8601 date strings for comparison
            let formatter = DateUtil.iso8601Formatter
            let date1 = formatter.date(from: entry1.date) ?? Date.distantPast
            let date2 = formatter.date(from: entry2.date) ?? Date.distantPast
            return date1 < date2
        }
        
        transcriptionList = combinedList
        
        // Individual services handle their own JSON saving automatically
        // No need to save combined JSON here
    }
    
    // Helper method to update Apple Speech display list (shows session transcriptions)
    private func updateAppleSpeechDisplayList() {
        // For Apple Speech, we show the session transcriptions during recording
        // (permanent history is handled separately and saved when stopping)
        let sessionList = speechRecognizerService.sessionTranscriptions
        appleSpeechHistory = sessionList.map { $0.transcription }
    }

}
