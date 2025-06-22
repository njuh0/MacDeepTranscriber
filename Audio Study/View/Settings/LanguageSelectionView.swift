import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        VStack(spacing: 12) {
            Text("Language Settings")
                .font(.headline)
                .foregroundColor(.primary)

            // Apple Speech Locale Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Speech Language")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Picker(
                    "Language",
                    selection: $audioCaptureService.selectedLocale
                ) {
                    ForEach(audioCaptureService.getSupportedLocalesWithNames(), id: \.0) { locale, name in
                        Text(name)
                            .tag(locale)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(audioCaptureService.isCapturing)
                .onChange(of: audioCaptureService.selectedLocale) { newLocale in
                    audioCaptureService.changeLocale(to: newLocale)
                }
                .frame(minWidth: 220)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

#Preview {
    LanguageSelectionView(audioCaptureService: AudioCaptureService())
}
