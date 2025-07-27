# MacDeepTranscriber

**MacDeepTranscriber is a powerful and efficient tool that turns your Mac into a smart audio processing station. Transcribe lectures, online content, or your own voice, and then use integrated AI to analyze, clean, and learn from the text.**

# Why it exists
I enjoy listening to audiobooks and learning languages. Occasionally, I miss a word or struggle to understand it. MacDeepTranscriber runs in the background while I listen to an audiobook or watch a video, allowing me to quickly check unfamiliar words or phrases.

## Record
- **Transcribe Anything**:
  - **Audiobooks & Online Content**: Capture and transcribe audio from YouTube, podcasts, and audiobooks.
  - **Live Conversations**: Record and analyze discussions from Discord, Zoom, or any other live audio source. (Sadly most likely you will not be able to use your microphone at the same time and record system audio. You will need to change the primary microphone every time in Audio MIDI Setup app)
  - **Lectures & Meetings**: Record in-person lectures or meetings and get a full text transcript for later analysis.
  - **Analyze Your Speech**: Record your own voice to get a transcript and identify areas for improvement. (Not advance, only words)

  - **Extensive Language Support**: Transcribe over 50 languages and dialects supported by Apple Speech.

https://github.com/user-attachments/assets/35da1b69-17ff-4cbc-891e-19734247aa15

## Enhance Transcriptions 
  - **Enhance Transcriptions**: Use AI to automatically correct errors, fix punctuation, and remove repetitive phrases from your raw transcriptions.

https://github.com/user-attachments/assets/7047bee2-bd02-4bc9-b4bc-731733e1dd99

## Word Sorter. Language Learning
  - **Filter & Export Vocabulary**: Use the Word Sorter to isolate words you don't know from any transcription and export them for study in apps like Anki or Quizlet.
  - **Correct**: The text can be corrected manually in the recording file.
  - **Word Sorter**: An intelligent tool that uses Apple's Natural Language framework to lemmatize words (e.g., "running" -> "run") and help you build vocabulary lists.


https://github.com/user-attachments/assets/3cbf8f57-dc66-4c82-a6d0-747ed7aa5797

## AI Chat & Settings
  - **Analyze Content**: Chat with an AI about your transcribed text to get summaries, ask questions, or gain deeper insights.

https://github.com/user-attachments/assets/6677ca6c-5274-40c9-bf47-fb295fff0e5f


## Key Features

- **On-Device Transcription**: Powered by Apple's native Speech framework for fast, private, and efficient audio-to-text conversion.
- **System Audio Capture**: With the help of [BlackHole](https://github.com/ExistentialAudio/BlackHole), a free virtual audio driver, you can capture any audio playing on your Mac. You can also record directly from your microphone without it.
- **Extensive Language Support**: Transcribe over 50 languages and dialects supported by Apple Speech.
- **Integrated AI Models**: 
  - **Google Gemini 2.5 Flash**: For top-tier analysis and transcription enhancement. FREE DAILY REQUESTS
  - **Zhipu GLM-4-Flash**: A fast and efficient alternative for quick tasks. FREE DAILY REQUESTS
- **Privacy**: Your audio, and API keys are all processed and stored locally on your device. But transcripted text is sent to remote server if you enhance it or use AI Chat

## The Power of Native Apple Speech

MacDeepTranscriber is built on Apple's native Speech Recognition framework, which offers significant advantages:

- **Efficiency**: It is incredibly lightweight and consumes minimal RAM compared to other popular models like Whisper MLX. This means you can run it seamlessly in the background without slowing down your Mac.
- **Speed**: Get real-time transcriptions with very low latency.
- **Privacy**: All processing is done on-device, ensuring your data remains private.
- **Cost-Effective**: It's completely free to use, with no processing limits.

## Getting Started

### Capturing system audio tutorial
1. Download BlackHole for MacOS
2. Setup via Audio MIDI Setup.app
   
https://github.com/user-attachments/assets/54104d92-9913-4a9c-aeb2-9acba56f0dbf


### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- (Optional) [BlackHole](https://github.com/ExistentialAudio/BlackHole) for capturing system audio.

### Privacy
Apple's own Speech framework only works through a microphone. Even if you use BlackHole and want to record system audio, it requires access to a microphone (MacOS doesn't allow you to directly record system audio, the only option I found was to use BlackHole).

<img width="287" height="347" alt="Screen Shot 2025-07-27 at 18 53 18 PM" src="https://github.com/user-attachments/assets/5098815b-f4f2-4ade-880b-7f30ac3b1878" />
<img width="289" height="281" alt="Screen Shot 2025-07-27 at 18 53 32 PM" src="https://github.com/user-attachments/assets/83149578-3dcb-42ff-9468-0a1ad15a4ad4" />


### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/njuh0/MacDeepTranscriber.git
    cd MacDeepTranscriber
    ```

2.  **Open in Xcode:**
    ```bash
    open "MacDeepTranscriber.xcodeproj"
    ```

3.  **Run the app:** Press `Cmd+R`.

The easiest project in my life. The app was created 90% with the help of Claude Sonnet 4 Agent

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
