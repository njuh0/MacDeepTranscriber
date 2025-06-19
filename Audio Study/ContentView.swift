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
                    .contentShape(Rectangle())                        .onTapGesture {
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
            
            // WhisperKit Model Selection (only if WhisperKit is selected)
            if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
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
            }

            // Speech Engine Configuration
            // Apple Speech Settings (visible when Apple Speech is enabled)
            if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
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
            
            // WhisperKit Configuration (only if WhisperKit is selected)
            if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
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
        }

        VStack(spacing: 10) {
            // No engines selected message
            if audioCaptureService.selectedSpeechEngines.isEmpty {
                Text("No speech engines selected")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            } else {
                // WhisperKit Output (in its own scrollable container)
                if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("WhisperKit Output:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ScrollViewReader { whisperProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 4) {
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
                            }
                            .onChange(of: audioCaptureService.recognizedText) { _ in
                                // Auto-scroll to bottom when new text is added
                                if !audioCaptureService.recognizedText.isEmpty {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        whisperProxy.scrollTo("transcriptionText", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) ? 120 : 180)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
                
                // Apple Speech Output (in its own scrollable container)
                if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Apple Speech Output:")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ScrollViewReader { appleProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 4) {
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
                            .onChange(of: audioCaptureService.appleSpeechText) { _ in
                                // Auto-scroll to bottom when new text is added
                                if !audioCaptureService.appleSpeechText.isEmpty {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        appleProxy.scrollTo("appleSpeechText", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: audioCaptureService.selectedSpeechEngines.contains(.whisperKit) ? 120 : 180)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)

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
                // No engines selected
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
                    // No engines selected
                    else {
                        Text("Select a speech engine to see transcription history.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
            }
            .frame(maxHeight: 200)        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedHistoryTab == 0 ? Color.cyan : Color.green, lineWidth: 1)
        )
    }
    .padding(.horizontal)
    .padding(.bottom)
        }  // Close the conditional for hiding when no engines selected

        // Clear text and history buttons
        if !audioCaptureService.selectedSpeechEngines.isEmpty && 
           (!audioCaptureService.recognizedText.isEmpty || 
            !audioCaptureService.appleSpeechText.isEmpty ||
            !audioCaptureService.transcriptionList.isEmpty ||
            !audioCaptureService.appleSpeechHistory.isEmpty) {
            HStack {
                if !audioCaptureService.appleSpeechHistory.isEmpty && audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                    Button("Clear Apple Speech History") {
                        audioCaptureService.clearAppleSpeechHistory()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.green)
                }
                
                if !audioCaptureService.transcriptionList.isEmpty && audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    Button("Clear WhisperKit History") {
                        audioCaptureService.clearTranscriptionList()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.blue)
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
            // Model loading progress for WhisperKit (only if WhisperKit is selected)
            if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) && !audioCaptureService.isModelLoaded {
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
                audioCaptureService.selectedSpeechEngines.isEmpty ||
                !audioCaptureService.isMicrophoneAccessGranted ||
                (audioCaptureService.selectedSpeechEngines.contains(.whisperKit) && !audioCaptureService.isModelLoaded)
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
