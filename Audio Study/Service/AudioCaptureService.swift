import Foundation
import AVFoundation
import Speech // Import Speech framework
import Combine

@MainActor
class AudioCaptureService: ObservableObject {
    @Published var statusMessage: String = "Press 'Start' to begin audio capture..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?
    @Published var recognizedText: String = ""
    @Published var archivedText: String = ""  // Store archived text from buffer resets
    @Published var isSpeechRecognitionAvailable: Bool = false
    @Published var isMicrophoneAccessGranted: Bool = false
    @Published var selectedEngine: SpeechEngineType = .appleSpeech
    @Published var isWhisperKitProcessing: Bool = false
    @Published var modelLoadingProgress: Double = 0.0
    @Published var isModelLoaded: Bool = false
    @Published var selectedWhisperModel: String = "base"
    @Published var modelLoadingStatus: String = "Ready"
    @Published var transcriptionList: [String] = []
    
    // WhisperKit Configuration
    @Published var whisperTranscriptionInterval: TimeInterval = 15.0
    @Published var whisperMaxBufferDuration: TimeInterval = 120.0

    private var audioEngine: AVAudioEngine?
    private var speechRecognizerService: SpeechRecognizerService
    private var whisperKitService: WhisperKitService

    init() {
        speechRecognizerService = SpeechRecognizerService()
        whisperKitService = WhisperKitService()

        // Request microphone access early
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isMicrophoneAccessGranted = granted
                if granted {
                    print("Microphone access granted.")
                    self?.errorMessage = nil
                } else {
                    print("Microphone access denied.")
                    self?.errorMessage = AppError.microphonePermissionDenied.localizedDescription
                }
            }
        }
        
        setupSpeechRecognizerCallbacks()
        setupWhisperKitCallbacks()
        
        // Set initial availability based on selected engine
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
            
        whisperKitService.$transcriptionList
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcriptionList)
            
        // Sync initial model selection and configuration
        Task { @MainActor in
            if selectedWhisperModel != "base" {
                switchWhisperModel(to: selectedWhisperModel)
            }
            // Sync initial configuration values
            updateWhisperTranscriptionInterval(whisperTranscriptionInterval)
            updateWhisperMaxBufferDuration(whisperMaxBufferDuration)
        }
    }
    
    private func setupSpeechRecognizerCallbacks() {
        speechRecognizerService.onError = { [weak self] error in
            DispatchQueue.main.async {
                if self?.selectedEngine == .appleSpeech {
                    self?.errorMessage = error.localizedDescription
                    print("SpeechRecognizerService Error: \(error.localizedDescription)")
                }
            }
        }
        speechRecognizerService.onAvailabilityChange = { [weak self] available in
            DispatchQueue.main.async {
                if self?.selectedEngine == .appleSpeech {
                    self?.isSpeechRecognitionAvailable = available
                    print("Apple Speech Recognizer availability changed: \(available)")
                }
            }
        }
        speechRecognizerService.onRecognitionResult = { [weak self] text in
            DispatchQueue.main.async {
                if self?.selectedEngine == .appleSpeech {
                    self?.recognizedText = text
                }
            }
        }
    }
    
    private func setupWhisperKitCallbacks() {
        whisperKitService.onError = { [weak self] error in
            DispatchQueue.main.async {
                if self?.selectedEngine == .whisperKit {
                    self?.errorMessage = error.localizedDescription
                    print("WhisperKitService Error: \(error.localizedDescription)")
                }
            }
        }
        whisperKitService.onAvailabilityChange = { [weak self] available in
            DispatchQueue.main.async {
                if self?.selectedEngine == .whisperKit {
                    self?.isSpeechRecognitionAvailable = available
                    print("WhisperKit availability changed: \(available)")
                }
            }
        }
        whisperKitService.onRecognitionResult = { [weak self] text in
            DispatchQueue.main.async {
                if self?.selectedEngine == .whisperKit {
                    self?.recognizedText = text
                }
            }
        }
        whisperKitService.onArchivedTextUpdate = { [weak self] text in
            DispatchQueue.main.async {
                if self?.selectedEngine == .whisperKit {
                    self?.archivedText = text
                }
            }
        }
    }
    
    private func updateAvailability() {
        switch selectedEngine {
        case .appleSpeech:
            isSpeechRecognitionAvailable = speechRecognizerService.isRecognitionAvailable
        case .whisperKit:
            isSpeechRecognitionAvailable = whisperKitService.isAvailable
        }
    }
    
    func switchEngine(to engine: SpeechEngineType) {
        guard !isCapturing else {
            errorMessage = "Cannot switch engines while capturing. Stop capture first."
            return
        }
        
        selectedEngine = engine
        updateAvailability()
        recognizedText = "" // Clear previous results
        errorMessage = nil
        
        let engineName = engine.rawValue
        statusMessage = "Switched to \(engineName). Press 'Start' to begin capture."
        print("Switched to \(engineName)")
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
        statusMessage = "Transcription text cleared."
    }
    
    func clearArchivedText() {
        archivedText = ""
        statusMessage = "Archived text cleared."
    }

    func startCapture() {
        guard !isCapturing else { return }
        
        // Ensure microphone access is granted
        guard isMicrophoneAccessGranted else {
            errorMessage = AppError.microphonePermissionDenied.localizedDescription
            print("Cannot start capture: Microphone access denied.")
            return
        }

        // Ensure speech recognition is available before starting capture
        guard isSpeechRecognitionAvailable else {
            let engineName = selectedEngine.rawValue
            errorMessage = "\(engineName) is not available."
            print("Cannot start capture: \(engineName) not available.")
            return
        }

        if audioEngine != nil {
            stopCapture()
        }

        do {
            try configureAudioEngine()
            
            let recordingFormat = audioEngine!.inputNode.outputFormat(forBus: 0)
            
            // Start recognition with selected engine
            switch selectedEngine {
            case .appleSpeech:
                try speechRecognizerService.startRecognition(audioFormat: recordingFormat)
                statusMessage = "Audio capture active with Apple Speech Recognition. Listening..."
            case .whisperKit:
                try whisperKitService.startRecognition(audioFormat: recordingFormat)
                statusMessage = "Audio capture active with WhisperKit. Processing every 3s..."
            }
            
            isCapturing = true
            errorMessage = nil
            recognizedText = ""
            print("Capture started with \(selectedEngine.rawValue).")
        } catch {
            isCapturing = false
            stopCapture()
            if let appError = error as? AppError {
                errorMessage = appError.localizedDescription
            } else {
                errorMessage = AppError.genericError("An unexpected error occurred: \(error.localizedDescription)").localizedDescription
            }
            print("Error starting capture: \(error.localizedDescription)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }

        // Stop recognition based on selected engine
        switch selectedEngine {
        case .appleSpeech:
            speechRecognizerService.stopRecognition()
        case .whisperKit:
            whisperKitService.stopRecognition()
        }

        if let engine = audioEngine {
            engine.stop()
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        audioEngine = nil

        isCapturing = false
        statusMessage = "Audio capture and \(selectedEngine.rawValue) stopped."
        print("Capture stopped.")
    }

    private func configureAudioEngine() throws {
        print("Attempting to configure AVAudioEngine...")
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            print("Error: AVAudioEngine failed to initialize.")
            throw AppError.audioEngineSetupFailed
        }
        print("AVAudioEngine initialized.")

        let inputNode = engine.inputNode
        print("InputNode obtained. Number of inputs: \(inputNode.numberOfInputs)")
        
        if inputNode.numberOfInputs == 0 {
            print("Error: InputNode has no inputs. BlackHole might not be selected as system input.")
            throw AppError.inputDeviceNotConfigured
        }

        let recordingFormat: AVAudioFormat
        do {
            recordingFormat = inputNode.outputFormat(forBus: 0)
            print("Recording format obtained: Channels=\(recordingFormat.channelCount), SampleRate=\(recordingFormat.sampleRate)")
            guard recordingFormat.channelCount > 0 && recordingFormat.sampleRate > 0 else {
                print("Error: Invalid audio format (channels or sample rate are zero).")
                throw AppError.invalidAudioFormat
            }
        } catch {
            print("Error getting inputNode output format: \(error.localizedDescription)")
            throw AppError.invalidAudioFormat
        }

        // Install a tap on the input node and pass buffers to the selected engine
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            switch self.selectedEngine {
            case .appleSpeech:
                self.speechRecognizerService.appendAudioBuffer(buffer)
            case .whisperKit:
                Task { @MainActor in
                    self.whisperKitService.appendAudioBuffer(buffer)
                }
            }
        }
        print("InputNode tap installed on bus 0.")

        print("Preparing AVAudioEngine...")
        engine.prepare()
        print("AVAudioEngine prepared.")
        
        do {
            print("Starting AVAudioEngine...")
            try engine.start()
            print("AVAudioEngine started successfully.")
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 13 {
                print("Error starting AVAudioEngine: Permission denied (Microphone access).")
                throw AppError.microphonePermissionDenied
            } else {
                print("Fatal Error starting AVAudioEngine: \(nsError.localizedDescription) (Domain: \(nsError.domain), Code: \(nsError.code))")
                throw AppError.audioEngineSetupFailed
            }
        }
    }
}
