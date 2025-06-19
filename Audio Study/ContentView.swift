import SwiftUI

// Helper view for error display
struct ErrorBannerView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            if errorMessage.contains("Audio device") ||
               errorMessage.contains("CoreAudio") ||
               errorMessage.contains("-10877") {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Troubleshooting:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• Check your audio input device settings")
                    Text("• Restart the application")
                    Text("• Ensure BlackHole is properly installed")
                    Text("• Verify no other apps are exclusively using the audio device")
                }
                .font(.caption)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService()  // Simpler initialization
    @State private var selectedHistoryTab: Int = 0  // 0 - WhisperKit, 1 - Apple Speech

    var body: some View {
        VStack {
            Text("Record")
                .font(.largeTitle)
                .padding()
                
            // Parallel Speech Recognition Options
            VStack(spacing: 8) {
                Toggle(isOn: $audioCaptureService.useAppleSpeechInParallel) {
                    HStack {
                        Text("Use Apple Speech in parallel")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("Run native macOS speech recognition alongside WhisperKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.vertical, 4)
                .onChange(of: audioCaptureService.useAppleSpeechInParallel) { newValue in
                    audioCaptureService.toggleAppleSpeechParallel(newValue)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
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

            // Speech Engine Configuration
            // Apple Speech Settings (visible when Apple Speech is enabled)
            if audioCaptureService.useAppleSpeechInParallel {
                VStack(spacing: 12) {
                    Text("Apple Speech Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Language selection for Apple Speech
                    Picker(
                        "Language",
                        selection: $audioCaptureService.selectedLocale
                    ) {
                        ForEach(audioCaptureService.getSupportedLocalesWithNames(), id: \.0.identifier) { locale, name in
                            Text(name)
                                .tag(locale)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(audioCaptureService.isCapturing)
                    .onChange(of: audioCaptureService.selectedLocale) { newLocale in
                        audioCaptureService.changeLocale(to: newLocale)
                    }
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
        }

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // WhisperKit Output
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("WhisperKit Output:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if audioCaptureService.recognizedText.isEmpty {
                            Text("WhisperKit transcription will appear here...")
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
                    }
                    
                    // Apple Speech Output (only if enabled)
                    if audioCaptureService.useAppleSpeechInParallel {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Apple Speech Output:")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            if audioCaptureService.appleSpeechText.isEmpty {
                                Text("Apple Speech transcription will appear here...")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            } else {
                                Text(audioCaptureService.appleSpeechText)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .id("appleSpeechText")
                            }
                        }
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
            // Add scrolling for Apple Speech text too
            .onChange(of: audioCaptureService.appleSpeechText) { _ in
                if audioCaptureService.useAppleSpeechInParallel && !audioCaptureService.appleSpeechText.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("appleSpeechText", anchor: .bottom)
                    }
                }
            }
        }
        .frame(height: audioCaptureService.useAppleSpeechInParallel ? 200 : 120)
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
            
            // Tabs for switching between WhisperKit and Apple Speech history
            if audioCaptureService.useAppleSpeechInParallel {
                Picker("Transcription History", selection: Binding(
                    get: { self.selectedHistoryTab },
                    set: { self.selectedHistoryTab = $0 }
                )) {
                    Text("WhisperKit History").tag(0)
                    Text("Apple Speech History").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            
            if audioCaptureService.useAppleSpeechInParallel {
                HStack {
                    Text(selectedHistoryTab == 0 ? "WhisperKit Segments:" : "Apple Speech History:")
                        .font(.subheadline)
                        .foregroundColor(selectedHistoryTab == 0 ? .blue : .green)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                HStack {
                    Text("WhisperKit Segments:")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
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
            }
            .frame(maxHeight: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedHistoryTab == 0 ? Color.cyan : Color.green, lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom)

        // Clear text and history buttons
        if !audioCaptureService.recognizedText.isEmpty || 
           !audioCaptureService.appleSpeechText.isEmpty ||
           !audioCaptureService.transcriptionList.isEmpty ||
           !audioCaptureService.appleSpeechHistory.isEmpty {
            HStack {
                if !audioCaptureService.appleSpeechHistory.isEmpty && audioCaptureService.useAppleSpeechInParallel {
                    Button("Clear Apple Speech History") {
                        audioCaptureService.clearAppleSpeechHistory()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("Clear Current Text") {
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
            ErrorBannerView(errorMessage: error)
                .padding(.top)
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
// Commenting out the preview to avoid circular reference issues
//#Preview {
//    ContentView()
//}
