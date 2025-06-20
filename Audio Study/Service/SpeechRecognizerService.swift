import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizerService: ObservableObject {
    @Published var isRecognizing: Bool = false
    @Published var recognizedText: String = ""
    @Published var sessionTranscriptions: [TranscriptionEntry] = [] // Updated type
    @Published var errorMessage: String?
    @Published var isAvailable: Bool = false
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")
    
    // Temporary storage during recording session
    private var permanentHistory: [TranscriptionEntry] = []
    
    private var previousRecognizedText: String = "" // Для отслеживания изменений
    private var significantChangeThreshold: Int = 5 // Минимальная разница в символах для сохранения

    // For handling continuous recognition
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var cancellables = Set<AnyCancellable>()
    
    // Available locales for speech recognition
    private(set) var availableLocales: [Locale] = []
    
    init() {
        setupSpeechRecognition()
        updateAvailableLocales()
        loadAppleHistoryFromJSON() // Load history
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveAppleHistoryToJSON() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("apple_history.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For readable JSON

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: getDocumentsDirectory(), withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create documents directory: \(error.localizedDescription)")
            return
        }

        do {
            let data = try encoder.encode(self.permanentHistory)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("✅ Successfully saved Apple transcription history (\(self.permanentHistory.count) entries) to: \(fileURL.path)")
        } catch {
            print("❌ Error saving Apple transcription history to JSON: \(error.localizedDescription)")
            print("❌ File path: \(fileURL.path)")
        }
    }
    
    /// Saves session transcriptions to JSON in real-time (during recording)
    private func saveAppleHistoryToJSONRealTime() {
        let documentsDir = getDocumentsDirectory()
        let fileURL = documentsDir.appendingPathComponent("apple_history_session.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        print("🔍 Apple Speech real-time save attempt:")
        print("  📁 Documents directory: \(documentsDir.path)")
        print("  📄 File URL: \(fileURL.path)")
        print("  📊 Session transcriptions count: \(sessionTranscriptions.count)")

        // Create directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true, attributes: nil)
            print("  ✅ Documents directory confirmed/created")
        } catch {
            print("  ❌ Failed to create documents directory: \(error.localizedDescription)")
            return
        }

        // Save only session transcriptions during recording
        do {
            let data = try encoder.encode(sessionTranscriptions)
            try data.write(to: fileURL, options: [.atomicWrite])
            
            // Verify file was actually written
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int
            
            print("  ✅ Real-time saved Apple Speech session history (\(sessionTranscriptions.count) entries)")
            print("  📄 File exists: \(fileExists), Size: \(fileSize ?? 0) bytes")
            print("  📍 Full path: \(fileURL.path)")
        } catch {
            print("  ❌ Error saving Apple Speech session history to JSON (real-time): \(error.localizedDescription)")
            print("  ❌ File path: \(fileURL.path)")
        }
    }

    private func loadAppleHistoryFromJSON() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("apple_history.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Apple history JSON file does not exist. Starting with empty history.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.permanentHistory = try decoder.decode([TranscriptionEntry].self, from: data)
            print("Successfully loaded Apple transcription history from JSON. Count: \(self.permanentHistory.count)")
        } catch {
            print("Error loading Apple transcription history from JSON: \(error.localizedDescription). Starting with empty history.")
            self.permanentHistory = [] // Ensure clean state on error
        }
    }
    
    private func setupSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                switch status {
                case .authorized:
                    self.isAvailable = true
                    self.errorMessage = nil
                    self.setupRecognizer(with: self.selectedLocale)
                case .denied:
                    self.isAvailable = false
                    self.errorMessage = "Speech recognition authorization denied"
                case .restricted:
                    self.isAvailable = false
                    self.errorMessage = "Speech recognition is restricted on this device"
                case .notDetermined:
                    self.isAvailable = false
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.isAvailable = false
                    self.errorMessage = "Unknown authorization status for speech recognition"
                }
            }
        }
    }
    
    private func updateAvailableLocales() {
        availableLocales = SFSpeechRecognizer.supportedLocales().sorted(by: { 
            $0.identifier < $1.identifier 
        })
    }
    
    func changeLocale(to locale: Locale) {
        selectedLocale = locale
        setupRecognizer(with: locale)
    }
    
    private func setupRecognizer(with locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.supportsOnDeviceRecognition = true
    }
    
    func startRecognition() async throws {
        guard !isRecognizing else { return }
        
        // Check availability
        guard isAvailable, let recognizer = speechRecognizer else {
            throw NSError(
                domain: "SpeechRecognizerService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition is not available"]
            )
        }
        
        // Reset any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
                
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.requiresOnDeviceRecognition = true
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.addsPunctuation = true
        
        // Start audio engine if it doesn't exist
        audioEngine = AVAudioEngine()
        
        // Configure audio input
        let inputNode = audioEngine!.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install a tap on the audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start the audio engine
        audioEngine!.prepare()
        try audioEngine!.start()
        
        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    // Don't show cancellation errors as they are expected when stopping recognition
                    let nsError = error as NSError
                    
                    // Check for various cancellation and expected stop-related error patterns
                    let errorDescription = nsError.localizedDescription.lowercased()
                    let isExpectedStopError = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203 ||
                                            nsError.domain == "com.apple.speech.speechrecognitionerror" && nsError.code == 1 ||
                                            errorDescription.contains("cancel") ||
                                            errorDescription.contains("cancelled") ||
                                            errorDescription.contains("no speech detected")
                    
                    if isExpectedStopError {
                        // Recognition was cancelled or no speech detected - this is expected when stopping, not an error
                        print("🔕 Apple Speech recognition stopped (expected): \(error.localizedDescription)")
                    } else {
                        // Only show actual errors, not expected stop conditions
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                        print("❌ Apple Speech recognition error: \(error)")
                    }
                    self.stopRecognition()
                    return
                }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if(text.isEmpty){
                        print("No recognized text")
                    }
                    // Проверяем и сохраняем значительные изменения
                    self.checkAndSaveSignificantChange(newText: text)
                    self.recognizedText = text
                }
                
                if result?.isFinal == true {
                    // Add final result to session transcriptions
                    if let finalText = result?.bestTranscription.formattedString,
                       !finalText.isEmpty {
                        let entry = TranscriptionEntry(date: Date(), transcription: finalText)
                        self.sessionTranscriptions.append(entry)
                        print("Session transcription added (final): \(finalText)")
                        // Save to JSON immediately
                        self.saveAppleHistoryToJSONRealTime()
                    }
                    self.stopRecognition()
                }
            }
        }
        
        isRecognizing = true
        errorMessage = nil
    }
    
    func stopRecognition() {
        print("🛑 Apple Speech: stopRecognition called")
        
        // Add final recognized text to session transcriptions if it's not empty 
        // and different from the last entry in the session.
        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📝 Final recognized text: '\(finalText)'")
        
        if !finalText.isEmpty {
            if sessionTranscriptions.last?.transcription != finalText {
                let entry = TranscriptionEntry(date: Date(), transcription: finalText)
                sessionTranscriptions.append(entry)
                print("✅ Session transcription added (stopRecognition): \(finalText)")
                // Save to JSON immediately
                saveAppleHistoryToJSONRealTime()
            } else {
                print("🚫 Final text already exists in session, not adding duplicate")
            }
        } else {
            print("🚫 No final text to add to session")
        }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecognizing = false
        errorMessage = nil // Clear any error message when stopping normally
        
        // Don't clear session here - it should remain visible in UI until explicitly saved to permanent storage
        print("✅ Apple Speech recognition stopped. Session transcriptions count: \(sessionTranscriptions.count)")
    }
    
    func clearRecognizedText(clearHistory: Bool = false, clearSession: Bool = false) {
        recognizedText = ""
        previousRecognizedText = ""
        if clearHistory {
            permanentHistory = []
        }
        if clearSession {
            sessionTranscriptions = []
        }
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        sessionTranscriptions.removeAll()
        previousRecognizedText = ""
        print("Started new Apple Speech session")
    }
    
    func saveSessionToPermanentStorage() {
        // Move session transcriptions to permanent history
        permanentHistory.append(contentsOf: sessionTranscriptions)
        
        // Save to JSON file
        saveAppleHistoryToJSON()
        
        print("Saved \(sessionTranscriptions.count) Apple Speech transcriptions to permanent storage")
        
        // Don't clear session here - keep them visible in UI until new session starts
        print("Session transcriptions saved but kept visible in UI")
    }
    
    // Clear session transcriptions (call after saving or when starting new session)
    func clearSessionTranscriptions() {
        sessionTranscriptions = []
        print("Session transcriptions cleared")
    }
    
    // Save all session transcriptions to permanent storage (call when stop capture is clicked)
    func saveSessionTranscriptionsToPermanentStorage() {
        print("💾 Apple Speech: saveSessionTranscriptionsToPermanentStorage called")
        print("📝 Current session transcriptions count: \(sessionTranscriptions.count)")
        
        if !sessionTranscriptions.isEmpty {
            print("📝 Session transcriptions to save:")
            for (index, entry) in sessionTranscriptions.enumerated() {
                print("  \(index + 1). [\(entry.date)] \(entry.transcription.prefix(50))...")
            }
        }
        
        // Add all session transcriptions to the permanent history (in memory only)
        let initialPermanentCount = permanentHistory.count
        permanentHistory.append(contentsOf: sessionTranscriptions)
        let finalPermanentCount = permanentHistory.count
        
        print("✅ Moved \(sessionTranscriptions.count) session transcriptions to permanent storage (in memory)")
        print("📊 Permanent history: \(initialPermanentCount) → \(finalPermanentCount) entries")
        
        // Session JSON file already contains all data via real-time saving
        // No additional JSON saving needed here
        print("📄 All data already saved in session JSON via real-time updates")
        
        // Don't clear session transcriptions here - keep them visible in UI
        // They will be cleared when starting a new recording session
        print("👁️ Session transcriptions moved but kept visible in UI")
    }
    
    // Get current session transcriptions
    func getSessionTranscriptions() -> [TranscriptionEntry] {
        return sessionTranscriptions
    }
    
    // Get session transcriptions as formatted text
    func getSessionTranscriptionsText() -> String {
        return sessionTranscriptions.map { $0.transcription }.joined(separator: "\n")
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
            return 0.1 // Return a small non-zero if one has words and the other doesn't after split, but were non-empty initially
        }
        
        let commonWords = words1.intersection(words2)
        let similarity = Double(commonWords.count) / Double(max(words1.count, words2.count))
        
        return similarity
    }
    
    // Get a list of all supported locales with their display names
    func getSupportedLocalesWithNames() -> [(Locale, String)] {
        return availableLocales.map { locale in
            let displayName = (locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
            return (locale, displayName)
        }.sorted { $0.1 < $1.1 }
    }
    
    // Check if the new transcription is significantly different from the previous one
    private func checkAndSaveSignificantChange(newText: String) {
        print("🔄 checkAndSaveSignificantChange called with newText: '\(newText.prefix(50))...'")
        
        let trimmedOldText = previousRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNewText = newText.trimmingCharacters(in: .whitespacesAndNewlines)

        print("📝 Comparing: OLD: '\(trimmedOldText.prefix(30))...' vs NEW: '\(trimmedNewText.prefix(30))...'")

        let shortTextMaxLength = 10 // Max length for a text to be considered "short"
        let similarityThresholdForShortText = 0.1 // Stricter threshold for short texts
        let similarityThresholdForLongText = 0.5 // Regular threshold for longer texts

        if !trimmedOldText.isEmpty && !trimmedNewText.isEmpty {
            // Check for divergence: neither text is a prefix of the other.
            if !trimmedNewText.hasPrefix(trimmedOldText) && !trimmedOldText.hasPrefix(trimmedNewText) {
                let similarity = calculateTextSimilarity(trimmedOldText, trimmedNewText)
                // Log the similarity and which threshold will be used
                var effectiveThreshold = similarityThresholdForLongText
                var textCategory = "long"
                if trimmedOldText.count < shortTextMaxLength {
                    effectiveThreshold = similarityThresholdForShortText
                    textCategory = "short"
                }
                print("🔍 Similarity: \(String(format: "%.2f", similarity)) for old ('\(textCategory)' text): '\(trimmedOldText)' | new: '\(trimmedNewText)'. Effective threshold: \(effectiveThreshold)")

                var shouldSaveOldText = false
                if trimmedOldText.count < shortTextMaxLength {
                    if similarity < similarityThresholdForShortText {
                        shouldSaveOldText = true
                    }
                } else {
                    if similarity < similarityThresholdForLongText {
                        shouldSaveOldText = true
                    }
                }

                print("📊 shouldSaveOldText: \(shouldSaveOldText)")

                if shouldSaveOldText {
                    if sessionTranscriptions.last?.transcription != trimmedOldText {
                        let entry = TranscriptionEntry(date: Date(), transcription: trimmedOldText)
                        sessionTranscriptions.append(entry)
                        print("➕ Session transcription added (similarity < \(effectiveThreshold)): \(trimmedOldText)")
                        print("📊 Session transcriptions count now: \(sessionTranscriptions.count)")
                        // Save to JSON immediately
                        saveAppleHistoryToJSONRealTime()
                    } else {
                        print("🚫 Old text already matches last session entry, not adding duplicate")
                    }
                } else {
                    print("🚫 Not saving old text (similarity too high or other criteria not met)")
                }
            } else {
                print("📝 Text similarity detected: one is prefix of another, not saving")
            }
        } else {
            print("📝 One of the texts is empty, not comparing")
        }
        previousRecognizedText = newText // Always update to the latest text from the recognizer
        print("✅ Updated previousRecognizedText to: '\(newText.prefix(50))...'")
    }
    

    
    // Start a new recording session (clears previous session transcriptions)
    func startNewRecordingSession() {
        clearSessionTranscriptions()
        clearRecognizedText()
        print("Started new recording session")
    }
}