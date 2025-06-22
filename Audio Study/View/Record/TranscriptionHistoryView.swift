import SwiftUI

struct TranscriptionHistoryView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header for Apple Speech History
            HStack {
                Text("Apple Speech History")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear History") {
                    audioCaptureService.clearAppleSpeechHistory()
                }
                .foregroundColor(.red)
                .disabled(audioCaptureService.appleSpeechHistory.isEmpty)
            }
            .padding(.horizontal)
            
            // Apple Speech transcription content
            appleSpeechContentView
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Apple Speech Content View
    @ViewBuilder
    private var appleSpeechContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                AppleSpeechTranscriptionListView(
                    transcriptions: audioCaptureService.appleSpeechHistory,
                    emptyMessage: "No Apple Speech transcriptions yet. Start recording to see results."
                )
            }
        }
        .frame(maxHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
        )
        .padding(.horizontal)
    }
}

// MARK: - Helper Views

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