import SwiftUI

struct WhisperKitSettingsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        // Group to hold both sections, only rendering if WhisperKit is selected
        if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
            VStack { // Use a VStack to stack Model Selection and Settings
                // WhisperKit Model Selection
                VStack(spacing: 8) {
                    Text("WhisperKit Model")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Picker(
                        "Model",
                        selection: $audioCaptureService.selectedWhisperModel
                    ) {
                        ForEach(WhisperKitService.availableModels(), id: \.self) {
                            model in
                            let info = WhisperKitService.modelInfo(for: model)
                            VStack(alignment: .leading) {
                                Text(model)
                                    .font(.caption)
                                Text("\(info.size) - \(info.description)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(audioCaptureService.isCapturing)
                    .onChange(of: audioCaptureService.selectedWhisperModel) {
                        newModel in
                        audioCaptureService.switchWhisperModel(to: newModel)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)

                // WhisperKit Configuration
                VStack(spacing: 12) {
                    Text("Processing Settings")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(spacing: 8) {
                        // Transcription Interval Setting
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Transcription Interval")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(
                                    "\(String(format: "%.1f", audioCaptureService.whisperTranscriptionInterval))s"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Slider(
                                value: $audioCaptureService
                                    .whisperTranscriptionInterval,
                                in: 0.0...30.0,
                                step: 0.1
                            ) {
                                Text("Transcription Interval")
                            } onEditingChanged: { editing in
                                if !editing {
                                    audioCaptureService
                                        .updateWhisperTranscriptionInterval(
                                            audioCaptureService
                                                .whisperTranscriptionInterval
                                        )
                                }
                            }
                            .disabled(audioCaptureService.isCapturing)

                            Text("How often to process audio (5-30s)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Max Buffer Duration Setting
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Buffer Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(
                                    "\(String(format: "%.0f", audioCaptureService.whisperMaxBufferDuration))s"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Slider(
                                value: $audioCaptureService
                                    .whisperMaxBufferDuration,
                                in: 10.0...300.0,
                                step: 10.0
                            ) {
                                Text("Max Buffer Duration")
                            } onEditingChanged: { editing in
                                if !editing {
                                    audioCaptureService
                                        .updateWhisperMaxBufferDuration(
                                            audioCaptureService
                                                .whisperMaxBufferDuration
                                        )
                                }
                            }
                            .disabled(audioCaptureService.isCapturing)

                            Text("Maximum audio buffer size (1-5 minutes)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .opacity(0.5)
                )
                .padding(.horizontal)
            } // End of outer VStack
        } // End of if .contains(.whisperKit)
    }
}
