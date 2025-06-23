//
//  WordSorterView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI
import Foundation

struct WordSorterView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @State private var showSidebar = true
    @State private var recordingsFolders: [String] = []
    @State private var selectedFolder: String? = nil
    @State private var transcriptions: [String: String] = [:]
    
    var body: some View {
        HStack(spacing: 0) {
            // Основное содержимое
            VStack(spacing: 20) {
                if let selectedFolder = selectedFolder {
                    // Показываем выбранную запись для сортировки слов
                    WordSorterContentView(
                        folderName: selectedFolder,
                        transcriptions: transcriptions
                    )
                } else {
                    // Placeholder когда ничего не выбрано
                    Text("Word Sorter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if recordingsFolders.isEmpty {
                        Text("No recordings available")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Placeholder content для пустого состояния
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
            
            // Сайдбар справа
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
        
        // Очищаем предыдущие транскрипции на главном потоке
        transcriptions = [:]
        
        Task {
            let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
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
                            
                            if let transcription = json?["transcription"] as? String, !transcription.isEmpty {
                                newTranscriptions["Apple Speech"] = transcription
                                print("Found Apple Speech transcription in \(file): \(transcription.prefix(50))...")
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
            let documentsPath = "/Users/njuh/Library/Containers/ee.sofuwaru.Audio-Study/Data/Documents"
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
                        // Проверяем, есть ли JSON файлы в папке
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
            
            // Заголовок записей
            if !recordingsFolders.isEmpty {
                Divider()
                
                Text("Recordings")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                
                // Список папок с записями
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
    
    // Сохраняемые данные
    @AppStorage("knownWords") private var knownWordsData: String = ""
    @AppStorage("unknownWords") private var unknownWordsData: String = ""
    
    // Состояние для таблиц
    @State private var knownWords: Set<String> = []
    @State private var unknownWords: Set<String> = []
    @State private var draggedWord: String? = nil
    
    // Слова из текущей транскрипции, которых нет в других таблицах
    private var currentTranscriptionWords: [String] {
        guard !transcriptions.isEmpty else { return [] }
        
        // Получаем все слова из транскрипций
        let allText = transcriptions.values.joined(separator: " ")
        let words = allText
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
        
        let uniqueWords = Set(words)
        
        // Возвращаем только те слова, которых нет в знакомых и незнакомых
        return Array(uniqueWords.subtracting(knownWords).subtracting(unknownWords)).sorted()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            HStack {
                Text(folderName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Статистика
                HStack(spacing: 16) {
                    Text("Known: \(knownWords.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    
                    Text("Current: \(currentTranscriptionWords.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    
                    Text("Unknown: \(unknownWords.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
            }
            .padding(.top)
            
            if transcriptions.isEmpty {
                Text("No transcriptions available for this recording")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Три таблицы
                HStack(spacing: 16) {
                    // Левая таблица - Знакомые слова
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
                    
                    // Средняя таблица - Слова из текущей транскрипции
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
                    
                    // Правая таблица - Незнакомые слова
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
                .frame(maxHeight: .infinity)
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
        // Загружаем знакомые слова
        if !knownWordsData.isEmpty {
            knownWords = Set(knownWordsData.components(separatedBy: ","))
        }
        
        // Загружаем незнакомые слова
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
        // Просто удаляем из других таблиц, слово останется в currentTranscriptionWords
        knownWords.remove(word)
        unknownWords.remove(word)
        saveWords()
    }
}

struct WordTableView: View {
    let title: String
    let words: [String]
    let color: Color
    let icon: String
    @Binding var draggedWord: String?
    let onWordDrop: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок таблицы
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text("\(words.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .foregroundColor(color)
                    .cornerRadius(6)
            }
            
            Divider()
                .background(color.opacity(0.5))
            
            // Список слов
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color.opacity(0.1))
                            .foregroundColor(color)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color.opacity(0.3), lineWidth: 1)
                            )
                            .scaleEffect(draggedWord == word ? 0.95 : 1.0)
                            .opacity(draggedWord == word ? 0.7 : 1.0)
                            .onDrag {
                                draggedWord = word
                                return NSItemProvider(object: word as NSString)
                            }
                            .animation(.easeInOut(duration: 0.2), value: draggedWord)
                    }
                    
                    if words.isEmpty {
                        Text("No words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let word = item as? String {
                    DispatchQueue.main.async {
                        onWordDrop(word)
                        draggedWord = nil
                    }
                }
            }
            return true
        }
    }
}

#Preview {
    WordSorterView(audioCaptureService: AudioCaptureService())
}