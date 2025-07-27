import Foundation
import AVFoundation
import Combine
import Speech
import AppKit

@MainActor
class AudioCaptureService: ObservableObject {
    @Published var statusMessage: String = "Press 'Start' to begin audio capture..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?
    @Published var recognizedText: String = ""
    @Published var isSpeechRecognitionAvailable: Bool = false
    @Published var isMicrophoneAccessGranted: Bool = false
    
    // Apple Speech text and history
    @Published var appleSpeechText: String = ""
    @Published var appleSpeechHistory: [String] = []
    
    // Apple Speech Configuration
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")

    private var audioEngine: AVAudioEngine?
    // Expose the service so ContentView can access locale info
    let speechRecognizerService: SpeechRecognizerService
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize services
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
        
        print("ℹ️ AudioCaptureService initialized with Apple Speech only")
    }
    
    private func setupCallbacks() {
        // Set initial availability
        updateAvailability()
        
        // Set up Apple Speech callbacks
        speechRecognizerService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                // Store in appleSpeechText and main recognizedText
                self?.appleSpeechText = text
                self?.recognizedText = text
            }
            .store(in: &cancellables)
            
        speechRecognizerService.$sessionTranscriptions // Apple Speech session history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (sessionHistory: [TranscriptionEntry]) in
                self?.updateAppleSpeechDisplayList()
            }
            .store(in: &cancellables)
            
        speechRecognizerService.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Apple Speech: \(error)"
            }
            .store(in: &cancellables)
            
        // Initialize display lists  
        Task { @MainActor [self] in
            updateAppleSpeechDisplayList()
        }
    }
    
    // Update availability based on Apple Speech
    private func updateAvailability() {
        isSpeechRecognitionAvailable = speechRecognizerService.isAvailable
    }
    
    // Apple Speech is always available and enabled
    var isAppleSpeechEnabled: Bool { true }

    func clearRecognizedText() {
        recognizedText = ""
        appleSpeechText = ""
        statusMessage = "Transcription text cleared."
        
        // Clear Apple Speech text
        speechRecognizerService.clearRecognizedText(clearHistory: false)
    }
    
    // Method to clear Apple Speech history
    func clearAppleSpeechHistory() {
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    // Method to clear duplicates in Apple Speech history
    func cleanupAppleSpeechDuplicates() {
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    // Method to clear transcription history
    func clearTranscriptionHistory() {
        // Clear Apple Speech history - it handles its own JSON files
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }
    
    
    func clearTranscriptionList() {
        // Clear Apple Speech history - it handles its own JSON files  
        speechRecognizerService.clearRecognizedText(clearHistory: true, clearSession: true)
    }

    func startCapture() {
        guard !isCapturing else { return }
        
        if audioEngine != nil {
            stopCapture()
        }

        do {
            // Start a new session (clears previous session data)
            startNewSession()
            
            // Configure audio engine
            try configureAudioEngine()
            
            // Start Apple Speech
            try startAppleSpeechCapture()
            statusMessage = "Apple Speech active. Processing..."
            
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
                default:
                    statusMessage = "⚠️ Failed to start audio capture"
                }
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
        
        // Stop Apple Speech recognition
        print("🛑 Stopping Apple Speech recognition...")
        speechRecognizerService.stopRecognition()
        print("✅ Apple Speech stopped. Session count: \(speechRecognizerService.sessionTranscriptions.count)")

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
    
    /// Stops capture and calls completion when engines are fully stopped
    func stopCaptureWithCompletion(_ completion: @escaping () -> Void) {
        guard isCapturing else { 
            completion()
            return 
        }

        print("🛑 AudioCaptureService: Starting stopCaptureWithCompletion process...")
        
        // Stop Apple Speech recognition
        print("🛑 Stopping Apple Speech recognition...")
        speechRecognizerService.stopRecognition()
        print("✅ Apple Speech stopped. Session count: \(speechRecognizerService.sessionTranscriptions.count)")

        // Ensure all async operations complete before calling completion
        Task {
            // Wait a brief moment for any final transcriptions to be processed
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
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
                print("✅ Capture stopped and session saved. Calling completion.")
                
                // Call completion after everything is done
                completion()
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
                errorMessage = "Apple Speech error: \(error.localizedDescription)"
            }
        }
    }
    
    private func stopAppleSpeech() {
        speechRecognizerService.stopRecognition()
    }
    
    // MARK: - Speech Engine Specific Methods
    
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

        print("Preparing AVAudioEngine...")
        engine.prepare()
        print("AVAudioEngine prepared.")
        
        do {
            print("Starting AVAudioEngine...")
            try engine.start()
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
    
    // MARK: - Session Management
    
    func saveSessionToPermanentStorage() {
        print("💾 AudioCaptureService: Starting saveSessionToPermanentStorage...")
        
        // Save Apple Speech session transcriptions
        let sessionCount = speechRecognizerService.sessionTranscriptions.count
        print("💾 Saving \(sessionCount) Apple Speech session transcriptions...")
        speechRecognizerService.saveSessionTranscriptionsToPermanentStorage()
        
        // Update the display lists (individual services save their own JSON)
        updateDisplay()
        
        print("✅ Session transcriptions saved to permanent storage and JSON updated")
        statusMessage = "Session transcriptions saved to storage"
    }
    
    private func updateDisplay() {
        // Apple Speech display update is handled automatically via @Published
        updateAppleSpeechDisplayList()
    }
    
    func startNewSession() {
        // Clear session data for Apple Speech
        speechRecognizerService.startNewRecordingSession()
        
        // Clear current text
        recognizedText = ""
        appleSpeechText = ""
        errorMessage = nil
        
        print("Started new recording session")
        statusMessage = "New session started"
    }
    
    // Helper method to update Apple Speech display list (shows session transcriptions)
    private func updateAppleSpeechDisplayList() {
        // For Apple Speech, we show the session transcriptions during recording
        // (permanent history is handled separately and saved when stopping)
        let sessionList = speechRecognizerService.sessionTranscriptions
        appleSpeechHistory = sessionList.map { $0.transcription }
    }
    
    // MARK: - Save Recording to Titled Folder
    
    /// Saves the current recording session by copying relevant JSON files to a titled folder
    func saveRecordingToTitledFolder(title: String) {
        let documentsDirectory = getDocumentsDirectory()
        let recordingFolderURL = documentsDirectory.appendingPathComponent("Recordings").appendingPathComponent(title)
        
        // Create the recordings folder structure
        do {
            try FileManager.default.createDirectory(at: recordingFolderURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ Created recording folder: \(recordingFolderURL.path)")
        } catch {
            print("❌ Error creating recording folder: \(error.localizedDescription)")
            return
        }
        
        // Copy JSON files for Apple Speech
        var copiedFiles: [String] = []
        
        // Read Apple Speech session transcriptions
        var appleSpeechTranscriptions: [TranscriptionEntry] = []
        let appleSpeechSourceURL = documentsDirectory.appendingPathComponent("apple_history_session.json")
        
        if FileManager.default.fileExists(atPath: appleSpeechSourceURL.path) {
            do {
                let data = try Data(contentsOf: appleSpeechSourceURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                appleSpeechTranscriptions = try decoder.decode([TranscriptionEntry].self, from: data)
                copiedFiles.append("Apple Speech transcriptions")
                print("✅ Loaded Apple Speech session transcriptions: \(appleSpeechTranscriptions.count) entries")
            } catch {
                print("❌ Error reading Apple Speech session JSON: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ Apple Speech session JSON file not found at: \(appleSpeechSourceURL.path)")
        }
        
        // Create recording data with Apple Speech transcriptions only
        let totalTranscriptions = appleSpeechTranscriptions.count
        let recordingData = RecordingMetadata(
            title: title,
            date: Date(),
            appleSpeechEnabled: true,
            appleSpeechLocale: selectedLocale.identifier,
            copiedFiles: copiedFiles,
            appleSpeechTranscriptions: appleSpeechTranscriptions,
            totalTranscriptions: totalTranscriptions
        )
        
        let recordingDataURL = recordingFolderURL.appendingPathComponent("recording.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(recordingData)
            try data.write(to: recordingDataURL)
            print("✅ Saved recording data to: \(recordingDataURL.path)")
            print("📊 Total transcriptions saved: \(totalTranscriptions)")
            print("📝 Apple Speech entries: \(appleSpeechTranscriptions.count)")
        } catch {
            print("❌ Error saving recording data: \(error.localizedDescription)")
        }
        
        // Update status message
        let totalCount = appleSpeechTranscriptions.count
        statusMessage = "Recording '\(title)' saved with \(totalCount) transcription(s)"
        print("✅ Recording saved successfully: \(title) with \(totalCount) total transcriptions")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Recordings Management
    
    /// Gets list of saved recordings
    func getSavedRecordings() -> [String] {
        let documentsDirectory = getDocumentsDirectory()
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)
            return contents.compactMap { url in
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    return url.lastPathComponent
                }
                return nil
            }.sorted()
        } catch {
            print("Error reading recordings directory: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Opens the recordings folder in Finder
    func openRecordingsFolder() {
        let documentsDirectory = getDocumentsDirectory()
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings")
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Open in Finder
        NSWorkspace.shared.open(recordingsDirectory)
    }

}
