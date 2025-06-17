import Foundation
import AVFoundation
import Speech // Import Speech framework

class AudioCaptureService: ObservableObject {
    @Published var statusMessage: String = "Press 'Start' to begin audio capture..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?
    @Published var recognizedText: String = "" // This will now be updated
    @Published var isSpeechRecognitionAvailable: Bool = false // Added for speech recognizer status
    @Published var isMicrophoneAccessGranted: Bool = false // Re-added for direct management

    private var audioEngine: AVAudioEngine?
    private var speechRecognizerService: SpeechRecognizerService // Instance of the new service

    init() {
        speechRecognizerService = SpeechRecognizerService() // Initialize first

        // Request microphone access early
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async { // Ensure UI updates happen on the main thread
                self?.isMicrophoneAccessGranted = granted
                if granted {
                    print("Microphone access granted.")
                    self?.errorMessage = nil // Clear any previous permission error
                } else {
                    print("Microphone access denied.")
                    self?.errorMessage = AppError.microphonePermissionDenied.localizedDescription
                }
            }
        }
        
        // Set up callbacks to get updates from the speech recognizer service
        speechRecognizerService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error.localizedDescription
                print("SpeechRecognizerService Error: \(error.localizedDescription)")
            }
        }
        speechRecognizerService.onAvailabilityChange = { [weak self] available in
            DispatchQueue.main.async {
                self?.isSpeechRecognitionAvailable = available
                print("Speech Recognizer availability changed: \(available)")
            }
        }
        // --- NEW: Subscribe to recognition results ---
        speechRecognizerService.onRecognitionResult = { [weak self] text in
            DispatchQueue.main.async {
                self?.recognizedText = text // Update the published recognizedText
            }
        }

        // Immediately set the initial availability state
        isSpeechRecognitionAvailable = speechRecognizerService.isRecognitionAvailable
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
            errorMessage = AppError.speechRecognizerNotAvailable.localizedDescription
            print("Cannot start capture: Speech recognition not available.")
            return
        }

        if audioEngine != nil {
            stopCapture()
        }

        do {
            try configureAudioEngine() // This will start the audio engine
            
            // Pass the recording format to the speech recognizer service
            // This format must match the one used by the audio engine's tap.
            let recordingFormat = audioEngine!.inputNode.outputFormat(forBus: 0) // We know it's safe to unwrap after configureAudioEngine()
            try speechRecognizerService.startRecognition(audioFormat: recordingFormat)
            
            isCapturing = true
            statusMessage = "Audio capture active and speech recognition started. Listening..."
            errorMessage = nil
            recognizedText = "" // Clear previous recognition text when starting
            print("Capture started.")
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

        // Stop speech recognition first
        speechRecognizerService.stopRecognition()

        if let engine = audioEngine {
            engine.stop()
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
        }
        audioEngine = nil

        isCapturing = false
        statusMessage = "Audio capture and speech recognition stopped."
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

        // Install a tap on the input node and pass buffers to the speech recognizer
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            // Pass the buffer to the speech recognizer service
            self?.speechRecognizerService.appendAudioBuffer(buffer)
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
