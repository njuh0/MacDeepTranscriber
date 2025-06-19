import Foundation
import AVFoundation
import Combine

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
    @Published var transcriptionList: [String] = []
    
    // WhisperKit Configuration
    @Published var whisperTranscriptionInterval: TimeInterval = 15.0
    @Published var whisperMaxBufferDuration: TimeInterval = 120.0

    private var audioEngine: AVAudioEngine?
    private var whisperKitService: WhisperKitService

    init() {
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
                }
            }
        }
        
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
    
    private func updateAvailability() {
        isSpeechRecognitionAvailable = whisperKitService.isAvailable
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
    
    func clearTranscriptionList() {
        transcriptionList = []
    }

    func startCapture() {
        guard !isCapturing else { return }
        
        if audioEngine != nil {
            stopCapture()
        }

        do {
            try configureAudioEngine()
            
            let recordingFormat = audioEngine!.inputNode.outputFormat(forBus: 0)
            
            // Start recognition with WhisperKit
            try whisperKitService.startRecognition(audioFormat: recordingFormat)
            statusMessage = "Audio capture active with WhisperKit. Processing..."
            
            isCapturing = true
            errorMessage = nil
            recognizedText = ""
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

        // Stop recognition with WhisperKit
        whisperKitService.stopRecognition()

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
                throw AppError.audioSessionError("Audio engine failed to start: \(nsError.localizedDescription)")
            }
        }
    }
}
