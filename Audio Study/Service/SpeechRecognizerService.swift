import Foundation
import Speech
import AVFoundation

enum AppError: Error, LocalizedError {
    case speechRecognizerNotAvailable
    case audioEngineSetupFailed
    case inputDeviceNotConfigured
    case invalidAudioFormat
    case microphonePermissionDenied
    case speechRecognitionTaskFailed(Error)
    case genericError(String)

    var localizedDescription: String {
        switch self {
        case .speechRecognizerNotAvailable:
            return "Speech recognition is not available on this device or for this language."
        case .audioEngineSetupFailed:
            return "Failed to set up the audio engine."
        case .inputDeviceNotConfigured:
            return "No audio input device is configured or available. Ensure BlackHole is selected as a system input."
        case .invalidAudioFormat:
            return "Invalid audio format from the input device."
        case .microphonePermissionDenied:
            return "Microphone access is denied. Please enable it in System Settings (Privacy & Security -> Microphone)."
        case .speechRecognitionTaskFailed(let error):
            return "Speech recognition task failed: \(error.localizedDescription)"
        case .genericError(let message):
            return message
        }
    }
}


// --- FIX START ---
// Make SpeechRecognizerService inherit from NSObject
class SpeechRecognizerService: NSObject {
// --- FIX END ---
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Callbacks for external observation
    var onError: ((Error) -> Void)?
    var onAvailabilityChange: ((Bool) -> Void)?
    var onRecognitionResult: ((String) -> Void)?

    @Published var isRecognitionAvailable: Bool = false

    override init() { // When inheriting from NSObject, override init() is often needed if you have a custom initializer
        // Initialize with default locale or specify one
        // speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer = SFSpeechRecognizer()

        // Call super.init() before accessing self properties
        super.init()

        // Check availability and set up availability handler
        speechRecognizer?.delegate = self // Make this class the delegate for availability changes

        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in // Added weak self capture list
            DispatchQueue.main.async { // Ensure UI updates happen on the main thread
                guard let self = self else { return } // Safely unwrap self
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorization granted.")
                    self.isRecognitionAvailable = true
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition authorization denied.")
                    self.isRecognitionAvailable = false
                    self.onError?(AppError.speechRecognizerNotAvailable)
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                    self.isRecognitionAvailable = false
                    self.onError?(AppError.speechRecognizerNotAvailable)
                }
                self.onAvailabilityChange?(self.isRecognitionAvailable) // Notify about initial availability
            }
        }
        
        // Set initial availability based on current recognizer state (might be nil)
        isRecognitionAvailable = speechRecognizer?.isAvailable ?? false
    }

    /// Starts a new speech recognition task.
    /// - Parameter audioFormat: The audio format of the buffers that will be appended.
    func startRecognition(audioFormat: AVAudioFormat) throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw AppError.speechRecognizerNotAvailable
        }
        
        if recognitionTask != nil {
            stopRecognition() // Stop any previous task
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true // Get results as they are being recognized

        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
        }

        // Start the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            if let result = result {
                self?.onRecognitionResult?(result.bestTranscription.formattedString)
                isFinal = result.isFinal
                print("Recognized Text: \(result.bestTranscription.formattedString) (Final: \(isFinal))")
            }
            
            if error != nil || isFinal {
                // If there's an error or the task is final, stop the recognition
                self?.stopRecognition()
                if let error = error {
                    self?.onError?(AppError.speechRecognitionTaskFailed(error))
                    print("Speech recognition error: \(error.localizedDescription)")
                }
                if isFinal {
                    print("Speech recognition task finished.")
                }
            }
        }
        print("Speech recognition task started.")
    }

    /// Appends an audio buffer to the recognition request.
    /// - Parameter audioBuffer: The audio buffer to append.
    func appendAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(audioBuffer)
    }

    /// Stops the current speech recognition task.
    func stopRecognition() {
        recognitionRequest?.endAudio() // Tell the request that no more audio will be appended
        recognitionTask?.cancel() // Cancel the task if it's still running
        recognitionTask = nil
        recognitionRequest = nil
        print("Speech recognition stopped.")
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognizerService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { // Ensure UI updates on main thread
            self.isRecognitionAvailable = available
            self.onAvailabilityChange?(available)
        }
    }
}
