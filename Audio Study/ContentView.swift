import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureService = AudioCaptureService()  // Simpler initialization
    @State private var selectedHistoryTab: Int = 0  // 0 - WhisperKit, 1 - Apple Speech

    var body: some View {
        ScrollView {
            VStack(spacing: 16) { // Added spacing to the main VStack
                Text("Record")
                    .font(.largeTitle)
                    .padding(.top) // Adjusted padding

                SpeechEngineSelectionView(audioCaptureService: audioCaptureService)

                // Unified Language Selection (shown when any engine is selected)
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    LanguageSelectionView(audioCaptureService: audioCaptureService)
                }

                // Conditional rendering for settings views
                if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    WhisperKitSettingsView(audioCaptureService: audioCaptureService)
                }
                
                if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                    AppleSpeechSettingsView(audioCaptureService: audioCaptureService)
                }

                TranscriptionOutputView(audioCaptureService: audioCaptureService)

                // Conditional rendering for history view
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    TranscriptionHistoryView(audioCaptureService: audioCaptureService, selectedHistoryTab: $selectedHistoryTab)
                }

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
