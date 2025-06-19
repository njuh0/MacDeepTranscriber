import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizerService: ObservableObject {
    @Published var isRecognizing: Bool = false
    @Published var recognizedText: String = ""
    @Published var transcriptionHistory: [TranscriptionEntry] = [] // Updated type
    @Published var errorMessage: String?
    @Published var isAvailable: Bool = false
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")
    
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

        do {
            let data = try encoder.encode(self.transcriptionHistory)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("Successfully saved Apple transcription history to \(fileURL.path)")
        } catch {
            print("Error saving Apple transcription history to JSON: \(error.localizedDescription)")
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
            self.transcriptionHistory = try decoder.decode([TranscriptionEntry].self, from: data)
            print("Successfully loaded Apple transcription history from JSON. Count: \(self.transcriptionHistory.count)")
        } catch {
            print("Error loading Apple transcription history from JSON: \(error.localizedDescription). Starting with empty history.")
            self.transcriptionHistory = [] // Ensure clean state on error
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
                    self.stopRecognition()
                    self.errorMessage = "Recognition error: \(error.localizedDescription)"
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
                    // Сохраняем финальный результат
                    if let finalText = result?.bestTranscription.formattedString,
                       !finalText.isEmpty {
                        let entry = TranscriptionEntry(date: Date(), transcription: finalText)
                        self.transcriptionHistory.append(entry)
                        self.saveAppleHistoryToJSON()
                    }
                    self.stopRecognition()
                }
            }
        }
        
        isRecognizing = true
        errorMessage = nil
    }
    
    func stopRecognition() {
        // Сохраняем текущий текст в историю, если он не пустой
        if !recognizedText.isEmpty &&
           (transcriptionHistory.isEmpty || transcriptionHistory.last?.transcription != recognizedText) {
            let entry = TranscriptionEntry(date: Date(), transcription: recognizedText)
            self.transcriptionHistory.append(entry)
            self.saveAppleHistoryToJSON()
        }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecognizing = false
    }
    
    func clearRecognizedText(clearHistory: Bool = false) {
        recognizedText = ""
        previousRecognizedText = ""
        if clearHistory {
            transcriptionHistory = []
            saveAppleHistoryToJSON() // Save the cleared history
        }
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
        // Если текст существенно короче предыдущего, это может означать сброс Apple Speech
        if previousRecognizedText.count > 0 && 
           previousRecognizedText.count - newText.count > significantChangeThreshold {
            // Сохраняем предыдущую транскрипцию в историю
            if !previousRecognizedText.isEmpty {
                let entry = TranscriptionEntry(date: Date(), transcription: previousRecognizedText)
                self.transcriptionHistory.append(entry)
                self.saveAppleHistoryToJSON()
            }
        } 
        // Или если текст стал значительно длиннее, сохраняем промежуточный результат
        else if newText.count - previousRecognizedText.count > 30 {
            if !previousRecognizedText.isEmpty {
                let entry = TranscriptionEntry(date: Date(), transcription: previousRecognizedText)
                self.transcriptionHistory.append(entry)
                self.saveAppleHistoryToJSON()
            }
        }
        
        previousRecognizedText = newText
    }
    
    // Получение полной истории транскрипций
    func getFullTranscriptionHistory() -> String {
        return transcriptionHistory.map { "\($0.transcription)\n\n--- Entry Date: \($0.date) ---" }.joined(separator: "\n")
    }
}
