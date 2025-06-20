import SwiftUI

struct ControlsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    
    // State for save recording sheet
    @State private var showSaveRecordingSheet = false
    @State private var isStoppingCapture = false

    var body: some View {
        VStack {
            // Clear text and history buttons
            if !audioCaptureService.selectedSpeechEngines.isEmpty &&
               (!audioCaptureService.recognizedText.isEmpty ||
                !audioCaptureService.appleSpeechText.isEmpty ||
                !audioCaptureService.whisperKitService.sessionTranscriptions.isEmpty ||
                !audioCaptureService.appleSpeechHistory.isEmpty) {
                HStack {
                    if !audioCaptureService.appleSpeechHistory.isEmpty && audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                        Button("Clear Apple Speech History") {
                            audioCaptureService.clearAppleSpeechHistory()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
                    }

                    if !audioCaptureService.whisperKitService.sessionTranscriptions.isEmpty && audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                        Button("Clear WhisperKit History") {
                            audioCaptureService.whisperKitService.clearSession()
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

            // Model loading progress and Start/Stop Button
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
                        // First stop the capture, then show save sheet
                        stopCaptureAndShowSaveSheet()
                    } else {
                        audioCaptureService.startCapture()
                    }
                }) {
                    Text(
                        isStoppingCapture ? "Stopping..." :
                        audioCaptureService.isCapturing
                            ? "Stop Capture" : "Start Capture"
                    )
                    .font(.title2)
                    .cornerRadius(10) // This might be better on a ButtonStyle
                }
                .disabled(
                    isStoppingCapture ||
                    audioCaptureService.selectedSpeechEngines.isEmpty ||
                    !audioCaptureService.isMicrophoneAccessGranted ||
                    (audioCaptureService.selectedSpeechEngines.contains(.whisperKit) && !audioCaptureService.isModelLoaded)
                )
            }
            .padding()
        }
        .sheet(isPresented: $showSaveRecordingSheet) {
            SaveRecordingSheet(isPresented: $showSaveRecordingSheet) { title in
                // Capture is already stopped, just save the recording
                audioCaptureService.saveRecordingToTitledFolder(title: title)
            }
        }
    }
    
    /// Stops capture first, then shows save sheet
    private func stopCaptureAndShowSaveSheet() {
        isStoppingCapture = true
        
        // Stop the capture and engines first, then show save sheet
        audioCaptureService.stopCaptureWithCompletion {
            isStoppingCapture = false
            showSaveRecordingSheet = true
        }
    }
}
