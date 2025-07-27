//
//  WordSorterView.swift
//  MacDeepTranscriber
//
//  Created on 20.06.2025.
//

import SwiftUI
import Foundation
import NaturalLanguage

struct WordSorterView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @State private var showSidebar = true
    @State private var recordingsFolders: [String] = []
    @State private var selectedFolder: String? = nil
    @State private var transcriptions: [String: String] = [:]
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 20) {
                if let selectedFolder = selectedFolder {
                    // Show selected recording for word sorting
                    WordSorterContentView(
                        folderName: selectedFolder,
                        transcriptions: transcriptions
                    )
                } else {
                    // Placeholder when nothing is selected
                    Text("Word Sorter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if recordingsFolders.isEmpty {
                        Text("No recordings available")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Placeholder content for empty state
                        VStack(spacing: 16) {
                            Image(systemName: "book.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("No recordings found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create some recordings to start sorting words from them")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    } else {
                        Text("Select a recording from the sidebar")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Placeholder content
                        VStack(spacing: 16) {
                            Image(systemName: "book.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Your word sorting will appear here")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Select a recording from the sidebar to start sorting words")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right sidebar
            if showSidebar && !recordingsFolders.isEmpty {
                WordSorterRightSidebarView(
                    recordingsFolders: recordingsFolders,
                    selectedFolder: $selectedFolder,
                    loadTranscriptions: loadTranscriptions
                )
                    .frame(width: 250)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .toolbar {            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    audioCaptureService.openRecordingsFolder()
                }) {
                    Image(systemName: "folder")
                        .font(.title2)
                }
                .help("Open Recordings Folder")
            }
            
            if !recordingsFolders.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.right")
                            .foregroundColor(.primary)
                    }
                    .help(showSidebar ? "Hide Right Sidebar" : "Show Right Sidebar")
                }
            }
        }
        .onAppear {
            loadRecordingsFolders()
        }
    }
    
    private func loadTranscriptions(for folderName: String) {
        print("Loading transcriptions for folder: \(folderName)")
        
        // Clear previous transcriptions on main thread
        transcriptions = [:]
        
        Task {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
                print("Could not get documents directory")
                return
            }
            let folderPath = "\(documentsPath)/Recordings/\(folderName)"
            let fileManager = FileManager.default
            
            var newTranscriptions: [String: String] = [:]
            
            do {
                print("Checking folder path: \(folderPath)")
                
                guard fileManager.fileExists(atPath: folderPath) else {
                    print("Folder does not exist: \(folderPath)")
                    return
                }
                
                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                print("Folder contents: \(folderContents)")
                
                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"
                        
                        do {
                            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            
                            // Processing appleSpeechTranscriptions array
                            if let appleSpeechTranscriptions = json?["appleSpeechTranscriptions"] as? [[String: Any]] {
                                let transcriptions = appleSpeechTranscriptions.compactMap { item in
                                    return item["transcription"] as? String
                                }
                                let combinedTranscription = transcriptions.joined(separator: " ")
                                if !combinedTranscription.isEmpty {
                                    newTranscriptions["Apple Speech"] = combinedTranscription
                                    print("Found Apple Speech transcription in \(file): \(combinedTranscription.prefix(50))...")
                                }
                            }
                            
                            if let aiTranscription = json?["aiEnhancedTranscription"] as? String, !aiTranscription.isEmpty {
                                newTranscriptions["AI Enhanced"] = aiTranscription
                                print("Found AI Enhanced transcription in \(file): \(aiTranscription.prefix(50))...")
                            }
                        } catch {
                            print("Error reading JSON file \(file): \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    self.transcriptions = newTranscriptions
                    print("Updated transcriptions: \(self.transcriptions.keys)")
                }
            } catch {
                print("Error loading transcriptions from folder \(folderName): \(error)")
            }
        }
    }
    
    private func loadRecordingsFolders() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
                print("Could not get documents directory")
                return
            }
            let recordingsPath = "\(documentsPath)/Recordings"
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: recordingsPath) else {
                print("Recordings folder does not exist at: \(recordingsPath)")
                return
            }
            
            do {
                let folderContents = try fileManager.contentsOfDirectory(atPath: recordingsPath)
                var foldersWithJSON: [String] = []
                
                for item in folderContents {
                    let itemPath = "\(recordingsPath)/\(item)"
                    var isDirectory: ObjCBool = false
                    
                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        // Check if there are JSON files in the folder
                        let folderContents = try fileManager.contentsOfDirectory(atPath: itemPath)
                        if folderContents.contains(where: { $0.hasSuffix(".json") }) {
                            foldersWithJSON.append(item)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.recordingsFolders = foldersWithJSON.sorted()
                }
            } catch {
                print("Error loading recordings folders: \(error)")
            }
        }
    }
}

struct WordSorterRightSidebarView: View {
    let recordingsFolders: [String]
    @Binding var selectedFolder: String?
    let loadTranscriptions: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Recordings header
            if !recordingsFolders.isEmpty {
                Divider()
                
                Text("Recordings")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                
                // List of recording folders
                List(recordingsFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundColor(.blue)
                        Text(folder)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        selectedFolder == folder ? 
                            Color.accentColor.opacity(0.2) : 
                            Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFolder = folder
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            loadTranscriptions(folder)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .leading
        )
    }
}

struct WordSorterContentView: View {
    let folderName: String
    let transcriptions: [String: String]
    
    // Saved data
    @AppStorage("knownWords") private var knownWordsData: String = ""
    @AppStorage("unknownWords") private var unknownWordsData: String = ""
    @AppStorage("useLemmatization") private var useLemmatization: Bool = true
    @AppStorage("useEnhancedTranscription") private var useEnhancedTranscription: Bool = true
    
    // State for tables
    @State private var knownWords: Set<String> = []
    @State private var unknownWords: Set<String> = []
    @State private var draggedWord: String? = nil
    
    // Get selected transcription
    private var selectedTranscription: String {
        if useEnhancedTranscription && transcriptions["AI Enhanced"] != nil {
            return transcriptions["AI Enhanced"] ?? ""
        } else {
            return transcriptions["Apple Speech"] ?? ""
        }
    }
    
    // Words from current transcription that are not in other tables
    private var currentTranscriptionWords: [String] {
        guard !selectedTranscription.isEmpty else { return [] }
        
        // Get words from selected transcription
        let words = useLemmatization ? extractAndLemmatizeWords(from: selectedTranscription) : extractSimpleWords(from: selectedTranscription)
        
        let uniqueWords = Set(words)
        
        // Return only words that are not in known and unknown
        return Array(uniqueWords.subtracting(knownWords).subtracting(unknownWords)).sorted()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(folderName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if transcriptions["AI Enhanced"] != nil {
                    HStack {
                        Toggle("AI Enhanced", isOn: $useEnhancedTranscription)
                            .toggleStyle(.switch)
                            .font(.caption)
                        
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            
            if transcriptions.isEmpty {
                Text("No transcriptions available for this recording")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Three tables
                VStack(spacing: 12) {
                    
                    HStack(alignment: .top, spacing: 16) {
                    // Left table - Known words
                    VStack(spacing: 8) {
                        // Empty space for alignment with center table
                        Color.clear
                            .frame(height: 20)
                        
                        WordTableView(
                            title: "I Know",
                            words: Array(knownWords).sorted(),
                            color: .green,
                            icon: "checkmark.circle.fill",
                            draggedWord: $draggedWord,
                            onWordDrop: { word in
                                moveWordToKnown(word)
                            }
                        )
                    }
                    
                    // Center table - Words from current transcription
                    VStack(spacing: 8) {
                        // Lemmatization toggle above the table
                        HStack(spacing: 8) {
                            Toggle("Smart processing", isOn: $useLemmatization)
                                .toggleStyle(.switch)
                                .font(.caption)
                            
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .help("When enabled, converts words to their base form (e.g., 'running' → 'run', 'better' → 'good') and filters only meaningful words: nouns, verbs, adjectives, and adverbs")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 20) // Fixed height for alignment
                        
                        WordTableView(
                            title: "Current Recording",
                            words: currentTranscriptionWords,
                            color: .blue,
                            icon: "doc.text.fill",
                            draggedWord: $draggedWord,
                            onWordDrop: { word in
                                moveWordToCurrent(word)
                            }
                        )
                    }
                    
                    // Right table - Unknown words
                    VStack(spacing: 8) {
                        // Empty space for alignment with center table
                        Color.clear
                            .frame(height: 20)
                        
                        WordTableView(
                            title: "Don't Know",
                            words: Array(unknownWords).sorted(),
                            color: .red,
                            icon: "questionmark.circle.fill",
                            draggedWord: $draggedWord,
                            onWordDrop: { word in
                                moveWordToUnknown(word)
                            }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
                }
            }
        }
        .padding()
        .onAppear {
            loadSavedWords()
        }
        .onChange(of: knownWordsData) { _ in
            loadSavedWords()
        }
        .onChange(of: unknownWordsData) { _ in
            loadSavedWords()
        }
    }
    
    // MARK: - Data Management
    
    private func loadSavedWords() {
        // Load known words
        if !knownWordsData.isEmpty {
            knownWords = Set(knownWordsData.components(separatedBy: ","))
        }
        
        // Load unknown words
        if !unknownWordsData.isEmpty {
            unknownWords = Set(unknownWordsData.components(separatedBy: ","))
        }
    }
    
    private func saveWords() {
        knownWordsData = Array(knownWords).joined(separator: ",")
        unknownWordsData = Array(unknownWords).joined(separator: ",")
    }
    
    // MARK: - Word Movement
    
    private func moveWordToKnown(_ word: String) {
        unknownWords.remove(word)
        knownWords.insert(word)
        saveWords()
    }
    
    private func moveWordToUnknown(_ word: String) {
        knownWords.remove(word)
        unknownWords.insert(word)
        saveWords()
    }
    
    private func moveWordToCurrent(_ word: String) {
        // Simply remove from other tables, regardless of whether word is in current transcription
        // Word will appear in currentTranscriptionWords only if it's actually in the transcription
        knownWords.remove(word)
        unknownWords.remove(word)
        saveWords()
    }
    
    // MARK: - Natural Language Processing
    
    private func extractAndLemmatizeWords(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        
        var lemmatizedWords: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange])
            
            // Basic cleanup
            let cleanWord = word
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            // Check basic conditions
            guard cleanWord.count >= 3,
                  !cleanWord.isEmpty,
                  !cleanWord.allSatisfy(\.isNumber) else {
                return true
            }
            
            // Check that this is actually a word (not punctuation, numbers, etc.)
            let lexicalClassResult = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass)
            let lexicalClass = lexicalClassResult.0
            
            // Filter only nouns, verbs, adjectives and adverbs
            guard let tagValue = lexicalClass?.rawValue,
                  ["Noun", "Verb", "Adjective", "Adverb"].contains(tagValue) else {
                return true
            }
            
            // Получаем лемму (базовую форму)
            let lemmaResult = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma)
            if let lemma = lemmaResult.0?.rawValue {
                let cleanLemma = lemma.lowercased()
                if cleanLemma.count >= 3 && !cleanLemma.allSatisfy(\.isNumber) {
                    lemmatizedWords.append(cleanLemma)
                }
            } else {
                // Если лемма не найдена, используем очищенное слово
                lemmatizedWords.append(cleanWord)
            }
            
            return true
        }
        
        return lemmatizedWords
    }
    
    // MARK: - Simple Word Processing
    
    private func extractSimpleWords(from text: String) -> [String] {
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word in
                let cleanWord = word
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                if cleanWord.count >= 3 && !cleanWord.isEmpty && !cleanWord.allSatisfy(\.isNumber) {
                    return cleanWord
                }
                return nil
            }
    }
}

#Preview {
    WordSorterView(audioCaptureService: AudioCaptureService())
}