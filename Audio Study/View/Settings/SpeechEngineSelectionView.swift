import SwiftUI

struct SpeechEngineSelectionView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        // Speech Engine Selection
        VStack(spacing: 8) {
            Text("Speech Recognition Engines")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Select one or more speech recognition engines to use")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            ForEach(SpeechEngineType.allCases, id: \.self) { engine in
                HStack {
                    Image(systemName: audioCaptureService.selectedSpeechEngines.contains(engine) ? "checkmark.square.fill" : "square")
                        .foregroundColor(audioCaptureService.selectedSpeechEngines.contains(engine) ? .blue : .gray)
                        .imageScale(.large)

                    VStack(alignment: .leading) {
                        Text(engine.rawValue)
                            .font(.headline)

                        Text(engine.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    var updatedEngines = audioCaptureService.selectedSpeechEngines

                    if updatedEngines.contains(engine) {
                        // Allow deselecting any engine, even if it's the only one
                        updatedEngines.remove(engine)
                    } else {
                        updatedEngines.insert(engine)
                    }

                    audioCaptureService.updateSelectedSpeechEngines(updatedEngines)
                }
                .padding(.vertical, 8)
                .disabled(audioCaptureService.isCapturing)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .opacity(0.5)
        )
        .padding(.horizontal)
        .padding(.bottom)
    }
}
