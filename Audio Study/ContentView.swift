import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService() // Simpler initialization

    var body: some View {
        VStack {
            Text("BlackHole Audio to Text")
                .font(.largeTitle)
                .padding()
            
            // Engine Selection
            VStack(spacing: 8) {
                Text("Speech Recognition Engine")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Engine", selection: $audioCaptureService.selectedEngine) {
                    ForEach(SpeechEngineType.allCases, id: \.self) { engine in
                        HStack {
                            Text(engine.rawValue)
                        }
                        .tag(engine)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(audioCaptureService.isCapturing)
                .onChange(of: audioCaptureService.selectedEngine) { newValue in
                    audioCaptureService.switchEngine(to: newValue)
                }
                
                Text(audioCaptureService.selectedEngine.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // WhisperKit Model Selection (only show when WhisperKit is selected)
            if audioCaptureService.selectedEngine == .whisperKit {
                VStack(spacing: 8) {
                    Text("WhisperKit Model")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Model", selection: $audioCaptureService.selectedWhisperModel) {
                        ForEach(WhisperKitService.availableModels(), id: \.self) { model in
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
                    .onChange(of: audioCaptureService.selectedWhisperModel) { newModel in
                        audioCaptureService.switchWhisperModel(to: newModel)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                // WhisperKit Configuration (only show when WhisperKit is selected)
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
                                Text("\(String(format: "%.1f", audioCaptureService.whisperTranscriptionInterval))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $audioCaptureService.whisperTranscriptionInterval, in: 0.1...30.0, step: 0.1) {
                                Text("Transcription Interval")
                            } onEditingChanged: { editing in
                                if !editing {
                                    audioCaptureService.updateWhisperTranscriptionInterval(audioCaptureService.whisperTranscriptionInterval)
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
                                Text("\(String(format: "%.0f", audioCaptureService.whisperMaxBufferDuration))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $audioCaptureService.whisperMaxBufferDuration, in: 10.0...300.0, step: 10.0) {
                                Text("Max Buffer Duration")
                            } onEditingChanged: { editing in
                                if !editing {
                                    audioCaptureService.updateWhisperMaxBufferDuration(audioCaptureService.whisperMaxBufferDuration)
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
    
            Text(audioCaptureService.statusMessage)
                .font(.body)
                .padding(.horizontal)
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.bottom)

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
            
            // Archived text section (only show when WhisperKit is selected)
            if audioCaptureService.selectedEngine == .whisperKit {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Full transcription")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Clear Archived") {
                            audioCaptureService.clearArchivedText()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                        .disabled(audioCaptureService.archivedText.isEmpty)
                    }
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            if audioCaptureService.archivedText.isEmpty {
                                Text("Archived text from buffer resets will appear here...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            } else {
                                Text(audioCaptureService.archivedText)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    .padding(8)
                            }
                            
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxHeight: 400)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            
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
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            VStack(spacing: 8) {
                // Model loading progress for WhisperKit
                if audioCaptureService.selectedEngine == .whisperKit && !audioCaptureService.isModelLoaded {
                    VStack(spacing: 4) {
                        HStack {
                            Text(audioCaptureService.modelLoadingStatus)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(Int(audioCaptureService.modelLoadingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        ProgressView(value: audioCaptureService.modelLoadingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    Text("\(audioCaptureService.selectedEngine.rawValue): \(audioCaptureService.isSpeechRecognitionAvailable ? "Available" : "Loading...")")
                        .font(.caption)
                        .foregroundColor(audioCaptureService.isSpeechRecognitionAvailable ? .green : .orange)
                    
                    Spacer()
                    
                    if audioCaptureService.isWhisperKitProcessing && audioCaptureService.selectedEngine == .whisperKit {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Transcribing...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Button(action: {
                    if audioCaptureService.isCapturing {
                        audioCaptureService.stopCapture()
                    } else {
                        audioCaptureService.startCapture()
                    }
                }) {
                    Text(audioCaptureService.isCapturing ? "Stop Capture" : "Start Capture")
                        .font(.title2)
                        .padding()
                        .background(audioCaptureService.isCapturing ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!audioCaptureService.isSpeechRecognitionAvailable || !audioCaptureService.isMicrophoneAccessGranted || (audioCaptureService.selectedEngine == .whisperKit && !audioCaptureService.isModelLoaded))
            }
            .padding()

            if let error = audioCaptureService.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Instructions:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("• Apple Speech: Real-time recognition (requires internet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• WhisperKit: High-quality offline (native Swift, auto-downloads models)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Set 'Multi-Output Device' including BlackHole as 'Output'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Set 'BlackHole 2ch' as 'Input' in System Settings -> Sound")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .frame(minWidth: 500, minHeight: 1000) // Increased height for WhisperKit settings
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

