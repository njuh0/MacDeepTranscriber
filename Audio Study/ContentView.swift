import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService()  // Simpler initialization

    var body: some View {
        VStack {
            Text("Record")
                .font(.largeTitle)
                .padding()
            VStack(spacing: 8) {
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
                Text("WhisperKit Settings")
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
                            in: 0.1...30.0,
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
        }

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if audioCaptureService.recognizedText.isEmpty {
                        Text("Transcribed text will appear here...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text(audioCaptureService.recognizedText)
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding()
                            .id("transcriptionText")
                    }

                    Spacer(minLength: 0)
                }
            }
            .onChange(of: audioCaptureService.recognizedText) { _ in
                // Auto-scroll to bottom when new text is added
                if !audioCaptureService.recognizedText.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("transcriptionText", anchor: .bottom)
                    }
                }
            }
        }
        .frame(height: 100)
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom)

        // Previous transcriptions section
        VStack(alignment: .leading, spacing: 8) {
            Text("Previous Transcriptions")
                .font(.headline)
                .foregroundColor(.cyan)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    if audioCaptureService.transcriptionList.isEmpty {
                        Text("No previous transcriptions yet.")
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
            }
            .frame(maxHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan, lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom)

        // Clear text button
        if !audioCaptureService.recognizedText.isEmpty {
            HStack {
                Spacer()
                Button("Clear Text") {
                    audioCaptureService.clearRecognizedText()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()
            .padding(.bottom, 8)
        }

        VStack(spacing: 8) {
            // Model loading progress for WhisperKit
            if !audioCaptureService.isModelLoaded {
                VStack(spacing: 4) {
                    HStack {
                        Text(audioCaptureService.modelLoadingStatus)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text(
                            "\(Int(audioCaptureService.modelLoadingProgress * 100))%"
                        )
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    ProgressView(
                        value: audioCaptureService.modelLoadingProgress
                    )
                    .progressViewStyle(LinearProgressViewStyle())
                }
                .padding()
            }

            Button(action: {
                if audioCaptureService.isCapturing {
                    audioCaptureService.stopCapture()
                } else {
                    audioCaptureService.startCapture()
                }
            }) {
                Text(
                    audioCaptureService.isCapturing
                        ? "Stop Capture" : "Start Capture"
                )
                .font(.title2)
                .cornerRadius(10)
            }
            .disabled(
                !audioCaptureService.isSpeechRecognitionAvailable
                    || !audioCaptureService.isMicrophoneAccessGranted
                    || !audioCaptureService.isModelLoaded
            )
        }.padding()
        if let error = audioCaptureService.errorMessage {
            VStack {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                Spacer(minLength: 30)
            }
        }
        Spacer(minLength: 30)
        // Increased height for WhisperKit settings

    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
#Preview {
    ContentView()
}
