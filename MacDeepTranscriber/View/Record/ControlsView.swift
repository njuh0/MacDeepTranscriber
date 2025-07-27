import SwiftUI

struct ControlsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    
    // State for save recording sheet
    @State private var showSaveRecordingSheet = false
    @State private var isStoppingCapture = false

    var body: some View {
        VStack {
            // Clear text and history buttons (always shown)
            if !audioCaptureService.recognizedText.isEmpty ||
               !audioCaptureService.appleSpeechText.isEmpty ||
               !audioCaptureService.appleSpeechHistory.isEmpty {
                HStack {
                    if !audioCaptureService.appleSpeechHistory.isEmpty {
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

            // Model loading progress and Start/Stop Button
            VStack(spacing: 8) {
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
                    !audioCaptureService.isMicrophoneAccessGranted
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
