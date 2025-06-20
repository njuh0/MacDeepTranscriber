import SwiftUI

struct AppleSpeechSettingsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        // Apple Speech Settings (visible when Apple Speech is enabled)
        if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
            VStack(spacing: 12) {
                Text("Language selection is available in the unified Language Settings section above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
}
