import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) { // Added spacing to the main VStack
                Text("Record")
                    .font(.largeTitle)
                    .padding(.top) // Adjusted padding

                // Language Selection for Apple Speech
                LanguageSelectionView(audioCaptureService: audioCaptureService)
                
                // Transcription output
                TranscriptionOutputView(audioCaptureService: audioCaptureService)

                // Apple Speech transcription history
                TranscriptionHistoryView(audioCaptureService: audioCaptureService)

                // Controls
                ControlsView(audioCaptureService: audioCaptureService)

                if let error = audioCaptureService.errorMessage {
                    ErrorBannerView(errorMessage: error)
                        .padding(.top)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal) // Add horizontal padding to the VStack
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity) // Set a flexible frame for the ScrollView
    }
}

// Ensure Previews are removed if not needed or updated
// #Preview {
//     ContentView()
// }
