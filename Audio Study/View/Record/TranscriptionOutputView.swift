import SwiftUI

struct TranscriptionOutputView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        VStack(spacing: 10) {
            // Apple Speech Output (always shown)
            VStack(spacing: 0) {
                HStack {
                    Text("Apple Speech Output:")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal)

                ScrollViewReader { appleProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            if audioCaptureService.appleSpeechText.isEmpty {
                                Text("Apple Speech transcription will appear here...")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            } else {
                                Text(audioCaptureService.appleSpeechText)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .padding()
                                    .id("appleSpeechText")
                            }
                        }
                    }
                    .onChange(of: audioCaptureService.appleSpeechText) { _ in
                        // Auto-scroll to bottom when new text is added
                        if !audioCaptureService.appleSpeechText.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                appleProxy.scrollTo("appleSpeechText", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(height: 180)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
