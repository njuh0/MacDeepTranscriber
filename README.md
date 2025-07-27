# MacDeepTranscriber: Your AI-Powered Language Learning & Transcription Companion for macOS

**MacDeepTranscriber is a powerful and efficient tool that turns your Mac into a smart audio processing station. Transcribe lectures, online content, or your own voice, and then use integrated AI to analyze, clean, and learn from the text.**

---

## What Can You Do with MacDeepTranscriber?

MacDeepTranscriber is designed for a wide range of use cases, from language learning to professional work.

- **Transcribe Anything**: 
  - **Online Content**: Capture and transcribe audio from YouTube, podcasts, and audiobooks.
  - **Live Conversations**: Record and analyze discussions from Discord, Zoom, or any other live audio source.
  - **Lectures & Meetings**: Record in-person lectures or meetings and get a full text transcript for later analysis.

- **AI-Powered Text Analysis**:
  - **Enhance Transcriptions**: Use AI to automatically correct errors, fix punctuation, and remove repetitive phrases from your raw transcriptions.
  - **Analyze Content**: Chat with an AI about your transcribed text to get summaries, ask questions, or gain deeper insights.

- **Language Learning**:
  - **Analyze Your Speech**: Record your own voice (e.g., in a Discord call) to get a transcript and identify areas for improvement.
  - **Filter & Export Vocabulary**: Use the Word Sorter to isolate words you don't know from any transcription and export them for study in apps like Anki or Quizlet.

## Key Features

- **On-Device Transcription**: Powered by Apple's native Speech framework for fast, private, and efficient audio-to-text conversion.
- **System Audio Capture**: With the help of [BlackHole](https://github.com/ExistentialAudio/BlackHole), a free virtual audio driver, you can capture any audio playing on your Mac. You can also record directly from your microphone without it.
- **Extensive Language Support**: Transcribe over 50 languages and dialects supported by Apple Speech.
- **Integrated AI Models**: 
  - **Google Gemini 2.0 Flash**: For top-tier analysis and transcription enhancement.
  - **Zhipu GLM-4-Flash**: A fast and efficient alternative for quick tasks.
- **Word Sorter**: An intelligent tool that uses Apple's Natural Language framework to lemmatize words (e.g., "running" -> "run") and help you build vocabulary lists.
- **Privacy-Focused**: Your audio, transcriptions, and API keys are all processed and stored locally on your device.

## The Power of Native Apple Speech

MacDeepTranscriber is built on Apple's native Speech Recognition framework, which offers significant advantages:

- **Efficiency**: It is incredibly lightweight and consumes minimal RAM compared to other popular models like Whisper MLX. This means you can run it seamlessly in the background without slowing down your Mac.
- **Speed**: Get real-time transcriptions with very low latency.
- **Privacy**: All processing is done on-device, ensuring your data remains private.
- **Cost-Effective**: It's completely free to use, with no processing limits.

## Getting Started

### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- (Optional) [BlackHole](https://github.com/ExistentialAudio/BlackHole) for capturing system audio.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/Audio-Study.git
    cd Audio-Study
    ```

2.  **Open in Xcode:**
    ```bash
    open "MacDeepTranscriber.xcodeproj"
    ```

3.  **Run the app:** Press `Cmd+R`.

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
