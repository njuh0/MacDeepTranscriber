import SwiftUI

struct AppleSpeechSettingsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
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
    }
}
