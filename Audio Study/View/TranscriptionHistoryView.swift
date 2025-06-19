import SwiftUI

struct TranscriptionHistoryView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @Binding var selectedHistoryTab: Int

    var body: some View {
        // Previous transcriptions section (hide if no engines selected)
        if !audioCaptureService.selectedSpeechEngines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Previous Transcriptions")
                    .font(.headline)
                    .foregroundColor(.cyan)

                // Tabs for switching between WhisperKit and Apple Speech history
                // Only show tabs when both engines are selected
                if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) &&
                   audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    Picker("Transcription History", selection: $selectedHistoryTab) {
                        Text("WhisperKit History").tag(0)
                        Text("Apple Speech History").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    HStack {
                        Text(selectedHistoryTab == 0 ? "WhisperKit Segments:" : "Apple Speech History:")
                            .font(.subheadline)
                            .foregroundColor(selectedHistoryTab == 0 ? .blue : .green)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    HStack {
                        Text("WhisperKit Segments:")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                    HStack {
                        Text("Apple Speech History:")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else {
                    // No engines selected (This case should ideally not be hit if the parent `if` is true)
                    HStack {
                        Text("No speech engine selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        // When both engines are selected, show based on selected tab
                        if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) &&
                           audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {

                            if selectedHistoryTab == 0 {
                                // WhisperKit History
                                if audioCaptureService.transcriptionList.isEmpty {
                                    Text("No WhisperKit transcriptions yet.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(8)
                                } else {
                                    ForEach(
                                        audioCaptureService.transcriptionList.reversed(),
                                        id: \.self
                                    ) { text in
                                        Text(text)
                                            .font(.caption)
                                            .padding(8)
                                            .background(
                                                Color(NSColor.controlBackgroundColor)
                                            )
                                            .cornerRadius(8)
                                            .textSelection(.enabled)
                                    }
                                }
                            } else {
                                // Apple Speech History
                                if audioCaptureService.appleSpeechHistory.isEmpty {
                                    Text("No Apple Speech history yet.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(8)
                                } else {
                                    ForEach(
                                        audioCaptureService.appleSpeechHistory.reversed(),
                                        id: \.self
                                    ) { text in
                                        Text(text)
                                            .font(.caption)
                                            .padding(8)
                                            .background(
                                                Color(NSColor.controlBackgroundColor)
                                            )
                                            .cornerRadius(8)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                        // Only WhisperKit selected
                        else if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                            if audioCaptureService.transcriptionList.isEmpty {
                                Text("No WhisperKit transcriptions yet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            } else {
                                ForEach(
                                    audioCaptureService.transcriptionList.reversed(),
                                    id: \.self
                                ) { text in
                                    Text(text)
                                        .font(.caption)
                                        .padding(8)
                                        .background(
                                            Color(NSColor.controlBackgroundColor)
                                        )
                                        .cornerRadius(8)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        // Only Apple Speech selected
                        else if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                            if audioCaptureService.appleSpeechHistory.isEmpty {
                                Text("No Apple Speech history yet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            } else {
                                ForEach(
                                    audioCaptureService.appleSpeechHistory.reversed(),
                                    id: \.self
                                ) { text in
                                    Text(text)
                                        .font(.caption)
                                        .padding(8)
                                        .background(
                                            Color(NSColor.controlBackgroundColor)
                                        )
                                        .cornerRadius(8)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        // No engines selected (This case should ideally not be hit if the parent `if` is true)
                        else {
                            Text("Select a speech engine to see transcription history.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedHistoryTab == 0 ? Color.cyan : Color.green, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        } // Close the conditional for hiding when no engines selected
    }
}
