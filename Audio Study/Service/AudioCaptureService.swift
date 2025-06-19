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
    @Published var selectedSpeechEngines: Set<SpeechEngineType> = [.whisperKit]
    @Published var appleSpeechText: String = ""
    @Published var appleSpeechHistory: [String] = []
    
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
            
        speechRecognizerService.$transcriptionHistory // This is the property that needs to be observed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (history: [TranscriptionEntry]) in // Correctly expect [TranscriptionEntry]
                self?.transcriptionList = history // Assign to the correct property
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
        speechRecognizerService.clearRecognizedText(clearHistory: true)
    }
    
    func clearTranscriptionList() {
        transcriptionList = []
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
            
            // Clear previous text
            recognizedText = ""
            appleSpeechText = ""
            errorMessage = nil
            
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

        // Stop active engines based on selection
        if selectedSpeechEngines.contains(.whisperKit) {
            whisperKitService.stopRecognition()
        }
        
        if selectedSpeechEngines.contains(.appleSpeech) {
            speechRecognizerService.stopRecognition()
        }

        // Stop audio engine in any case
        if let engine = audioEngine {
            engine.stop()
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        audioEngine = nil

        isCapturing = false
        print("Capture stopped.")
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
    }
}
