import SwiftUI

struct SpeechEngineSelectionView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        // Apple Speech Engine Selection
        VStack(spacing: 8) {
            Text("Speech Recognition Engine")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Using Apple Speech Recognition for native macOS speech-to-text")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            HStack {
                Image(systemName: audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) ? "checkmark.square.fill" : "square")
                    .foregroundColor(audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) ? .green : .gray)
                    .imageScale(.large)

                VStack(alignment: .leading) {
                    Text("Apple Speech")
                        .font(.headline)

                    Text("Built-in macOS speech recognition - fast and reliable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                var updatedEngines = audioCaptureService.selectedSpeechEngines

                if updatedEngines.contains(.appleSpeech) {
                    updatedEngines.remove(.appleSpeech)
                } else {
                    updatedEngines.insert(.appleSpeech)
                }

                audioCaptureService.updateSelectedSpeechEngines(updatedEngines)
            }
            .padding(.vertical, 8)
            .disabled(audioCaptureService.isCapturing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .opacity(0.5)
        )
        .padding(.horizontal)
        .padding(.bottom)
        .onAppear {
            // Auto-select Apple Speech on first appear if nothing is selected
            if audioCaptureService.selectedSpeechEngines.isEmpty {
                audioCaptureService.updateSelectedSpeechEngines([.appleSpeech])
            }
        }
    }
}
