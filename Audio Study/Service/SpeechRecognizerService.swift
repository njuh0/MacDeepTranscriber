import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizerService: ObservableObject {
    @Published var isRecognizing: Bool = false
    @Published var recognizedText: String = ""
    @Published var transcriptionHistory: [String] = [] // Добавляем историю транскрипций
    @Published var errorMessage: String?
    @Published var isAvailable: Bool = false
    @Published var selectedLocale: Locale = Locale(identifier: "en-US")
    
    private var previousRecognizedText: String = "" // Для отслеживания изменений
    
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
                        self.transcriptionHistory.append(finalText)
                    }
                    self.stopRecognition()
                }
            }
        }
        
        isRecognizing = true
        errorMessage = nil
    }
    
    func stopRecognition() {
        // Save the current recognized text to history if it's not empty 
        // and different from the last entry in the history.
        // Also, trim whitespace to avoid saving empty or whitespace-only strings.
        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            if transcriptionHistory.last != finalText {
                transcriptionHistory.append(finalText)
                print("History added (stopRecognition): \(finalText)")
            }
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
        }
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
        let trimmedOldText = previousRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNewText = newText.trimmingCharacters(in: .whitespacesAndNewlines)

        let shortTextMaxLength = 10 // Max length for a text to be considered "short"
        let similarityThresholdForShortText = 0.2 // Stricter threshold for short texts
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
                print("Similarity: \(String(format: "%.2f", similarity)) for old ('\(textCategory)' text): '\(trimmedOldText)' | new: '\(trimmedNewText)'. Effective threshold: \(effectiveThreshold)")

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

                if shouldSaveOldText {
                    if transcriptionHistory.last != trimmedOldText {
                        transcriptionHistory.append(trimmedOldText)
                        print("History added (similarity < \(effectiveThreshold)): \(trimmedOldText)")
                    }
                }
            }
        }
        previousRecognizedText = newText // Always update to the latest text from the recognizer
    }
    
    // Получение полной истории транскрипций
    func getFullTranscriptionHistory() -> String {
        return transcriptionHistory.joined(separator: "\n")
    }
}
