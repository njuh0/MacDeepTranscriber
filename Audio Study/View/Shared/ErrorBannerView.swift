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
