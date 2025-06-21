//
//  TranscriptionsView.swift
//  Audio Study
//
//  Created on 21.06.2025.
//

import SwiftUI

struct TranscriptionsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @State private var showSidebar = true // Изначально открыт
    @State private var recordingsFolders: [String] = []
    @State private var selectedFolder: String? = nil
    @State private var transcriptions: [String: String] = [:] // engine: transcription
    
    var body: some View {
        HStack(spacing: 0) {
            // Основное содержимое
            VStack(spacing: 20) {
                if let selectedFolder = selectedFolder {
                    // Показываем выбранную транскрипцию
                    TranscriptionContentView(
                        folderName: selectedFolder,
                        transcriptions: transcriptions
                    )
                } else {
                    // Placeholder когда ничего не выбрано
                    Text("Transcriptions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Select a recording from the sidebar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Placeholder content
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Your transcriptions will appear here")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Select a recording from the sidebar to view transcription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Сайдбар справа
            if showSidebar {
                RightSidebarView(
                    audioCaptureService: audioCaptureService,
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .foregroundColor(.primary)
                }
                .help(showSidebar ? "Hide Sidebar" : "Show Sidebar")
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
                    await MainActor.run {
                        self.transcriptions = [:]
                    }
                    return
                }
                
                let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                print("Found files in folder: \(folderContents)")
                
                for file in folderContents {
                    if file.hasSuffix(".json") && !file.contains("recording_info") {
                        let filePath = "\(folderPath)/\(file)"
                        print("Reading JSON file: \(filePath)")
                        
                        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                        
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("JSON structure keys: \(json.keys)")
                            
                            // Парсим Apple Speech транскрипции
                            if let appleSpeechTranscriptions = json["appleSpeechTranscriptions"] as? [[String: Any]] {
                                let transcriptions = appleSpeechTranscriptions.compactMap { item in
                                    item["transcription"] as? String
                                }.joined(separator: "\n")
                                
                                if !transcriptions.isEmpty {
                                    newTranscriptions["Apple Speech"] = transcriptions
                                    print("Added Apple Speech transcriptions: \(appleSpeechTranscriptions.count) items")
                                }
                            }
                            
                            // Парсим WhisperKit транскрипции
                            if let whisperKitTranscriptions = json["whisperKitTranscriptions"] as? [[String: Any]] {
                                let transcriptions = whisperKitTranscriptions.compactMap { item in
                                    item["transcription"] as? String
                                }.joined(separator: "\n")
                                
                                if !transcriptions.isEmpty {
                                    newTranscriptions["WhisperKit"] = transcriptions
                                    print("Added WhisperKit transcriptions: \(whisperKitTranscriptions.count) items")
                                }
                            }
                        } else {
                            print("Failed to parse JSON from file: \(file)")
                        }
                    }
                }
                
                print("Total transcriptions loaded: \(newTranscriptions.count)")
                
                // Обновляем UI на главном потоке
                await MainActor.run {
                    self.transcriptions = newTranscriptions
                }
            } catch {
                print("Error loading transcriptions: \(error)")
                await MainActor.run {
                    self.transcriptions = [:]
                }
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

struct RightSidebarView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
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
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
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

struct TranscriptionContentView: View {
    let folderName: String
    let transcriptions: [String: String]
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок с названием записи
            Text(folderName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            if transcriptions.isEmpty {
                // Загрузка
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading transcription...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if transcriptions.count == 1 {
                // Одна транскрипция
                let (engine, transcription) = transcriptions.first!
                SingleTranscriptionView(engine: engine, transcription: transcription)
            } else {
                // Две транскрипции рядом
                HStack(spacing: 20) {
                    ForEach(Array(transcriptions.keys.sorted()), id: \.self) { engine in
                        if let transcription = transcriptions[engine] {
                            SingleTranscriptionView(engine: engine, transcription: transcription)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SingleTranscriptionView: View {
    let engine: String
    let transcription: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок движка
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.accentColor)
                Text(engine.capitalized)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            // Текст транскрипции
            ScrollView {
                Text(transcription)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

#Preview {
    TranscriptionsView(audioCaptureService: AudioCaptureService())
}
