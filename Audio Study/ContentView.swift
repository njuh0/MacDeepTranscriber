import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService() // Simpler initialization

    var body: some View {
        VStack {
            Text("BlackHole Audio to Text")
                .font(.largeTitle)
                .padding()

            Text(audioCaptureService.statusMessage)
                .font(.body)
                .padding(.horizontal)
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.bottom)

            Text(audioCaptureService.recognizedText)
                .font(.title3)
                .padding()
                .frame(minHeight: 150)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom)
            
            HStack {
                Text("Speech Recognition: \(audioCaptureService.isSpeechRecognitionAvailable ? "Available" : "Unavailable")")
                    .font(.caption)
                    .foregroundColor(audioCaptureService.isSpeechRecognitionAvailable ? .green : .red)
                
                Spacer()

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
                // Disable button if speech recognition OR microphone access is not available
                .disabled(!audioCaptureService.isSpeechRecognitionAvailable || !audioCaptureService.isMicrophoneAccessGranted)
            }
            .padding()

            if let error = audioCaptureService.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }

            Text("Ensure 'Multi-Output Device' including BlackHole is selected as 'Output' AND 'BlackHole 2ch' is selected as 'Input' in 'System Settings' -> 'Sound'.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(minWidth: 400, minHeight: 650) // Increased height slightly
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

