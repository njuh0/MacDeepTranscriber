import SwiftUI

struct TranscriptionHistoryView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @Binding var selectedHistoryTab: Int
    
    // Computed properties to break down complex logic
    private var hasWhisperKit: Bool {
        audioCaptureService.selectedSpeechEngines.contains(.whisperKit)
    }
    
    private var hasAppleSpeech: Bool {
        audioCaptureService.selectedSpeechEngines.contains(.appleSpeech)
    }
    
    private var hasBothEngines: Bool {
        hasWhisperKit && hasAppleSpeech
    }
    
    private var showEngineSelection: Bool {
        !audioCaptureService.selectedSpeechEngines.isEmpty
    }
    
    private var borderColor: Color {
        selectedHistoryTab == 0 ? .cyan : .green
    }

    var body: some View {
        if showEngineSelection {
            VStack(alignment: .leading, spacing: 8) {
                headerView
                tabSelectorView
                transcriptionContentView
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        Text("Previous Transcriptions")
            .font(.headline)
            .foregroundColor(.cyan)
    }
    
    // MARK: - Tab Selector View
    @ViewBuilder
    private var tabSelectorView: some View {
        if hasBothEngines {
            VStack(spacing: 4) {
                enginePicker
                tabHeaderText
            }
        } else {
            singleEngineHeader
        }
    }
    
    private var enginePicker: some View {
        Picker("Transcription History", selection: $selectedHistoryTab) {
            Text("WhisperKit History").tag(0)
            Text("Apple Speech History").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    private var tabHeaderText: some View {
        HStack {
            Text(selectedHistoryTab == 0 ? "WhisperKit Segments:" : "Apple Speech History:")
                .font(.subheadline)
                .foregroundColor(selectedHistoryTab == 0 ? .blue : .green)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var singleEngineHeader: some View {
        HStack {
            if hasWhisperKit {
                Text("WhisperKit Segments:")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            } else if hasAppleSpeech {
                Text("Apple Speech History:")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("No speech engine selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Transcription Content View
    private var transcriptionContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
                transcriptionListContent
            }
        }
        .frame(maxHeight: 200)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var transcriptionListContent: some View {
        if hasBothEngines {
            dualEngineContent
        } else if hasWhisperKit {
            whisperKitOnlyContent
        } else if hasAppleSpeech {
            appleSpeechOnlyContent
        } else {
            noEngineSelectedContent
        }
    }
    
    // MARK: - Content Views for Different Engine Configurations
    @ViewBuilder
    private var dualEngineContent: some View {
        if selectedHistoryTab == 0 {
            WhisperKitTranscriptionListView(
                transcriptions: audioCaptureService.transcriptionList,
                emptyMessage: "No WhisperKit transcriptions yet."
            )
        } else {
            AppleSpeechTranscriptionListView(
                transcriptions: audioCaptureService.appleSpeechHistory,
                emptyMessage: "No Apple Speech history yet."
            )
        }
    }
    
    private var whisperKitOnlyContent: some View {
        WhisperKitTranscriptionListView(
            transcriptions: audioCaptureService.transcriptionList,
            emptyMessage: "No WhisperKit transcriptions yet."
        )
    }
    
    private var appleSpeechOnlyContent: some View {
        AppleSpeechTranscriptionListView(
            transcriptions: audioCaptureService.appleSpeechHistory,
            emptyMessage: "No Apple Speech history yet."
        )
    }
    
    private var noEngineSelectedContent: some View {
        Text("Select a speech engine to see transcription history.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(8)
    }
}

// MARK: - Supporting Views
struct WhisperKitTranscriptionListView: View {
    let transcriptions: [TranscriptionEntry]
    let emptyMessage: String
    
    var body: some View {
        if transcriptions.isEmpty {
            Text(emptyMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
        } else {
            ForEach(transcriptions.reversed()) { entry in
                TranscriptionItemView(text: entry.transcription)
            }
        }
    }
}

struct AppleSpeechTranscriptionListView: View {
    let transcriptions: [String]
    let emptyMessage: String
    
    var body: some View {
        if transcriptions.isEmpty {
            Text(emptyMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
        } else {
            ForEach(transcriptions.reversed(), id: \.self) { text in
                TranscriptionItemView(text: text)
            }
        }
    }
}

struct TranscriptionItemView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .textSelection(.enabled)
    }
}
