# MacDeepTranscriber - macOS Speech Recognition App

**The application uses only Apple Speech for speech recognition.** The architecture has been simplified to focus on one reliable recognition engine.

## Features

- **Apple Speech Recognition** - built-in macOS speech recognition
- **Multilingual support** - support for all Apple Speech languages
- **Transcription history** - automatic saving of all history
- **Named recordings** - save recordings with custom names
- **Data export** - easy access to transcription JSON files
- **AI integration** - transcription analysis using GLM-4

## Requirements

- macOS 11.0+
- Xcode 13.0+
- Swift 5.5+
- Microphone access

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd "MacDeepTranscriber"
```

2. Open the project in Xcode:
```bash
open "MacDeepTranscriber.xcodeproj"
```

3. Run the project (⌘+R)

## Quick Start

1. **Check microphone permissions**: Make sure the app has permission to access the microphone in System Preferences > Security & Privacy > Privacy > Microphone

2. **Select language**: In settings, choose the desired language for Apple Speech recognition

3. **Start recording**: Click "Start Capture" to begin recording and recognition

## Project Structure

```
MacDeepTranscriber/
├── MacDeepTranscriber/
│   ├── Audio_StudyApp.swift         # Application entry point
│   ├── ContentView.swift            # Main view
│   ├── Model/
│   │   ├── AIModel.swift            # AI models and configuration
│   │   ├── AppError.swift           # Error handling
│   │   ├── NavigationModel.swift    # Navigation model
│   │   ├── SpeechEngineType.swift   # Recognition engine types
│   │   └── TranscriptionModels.swift # Transcription models
│   ├── Service/
│   │   ├── AudioCaptureService.swift          # Main audio capture service
│   │   ├── GLMChatService.swift              # GLM AI integration
│   │   ├── SpeechRecognizerService.swift     # Apple Speech integration
│   │   ├── TranscriptionPersistenceService.swift # Data persistence
│   │   └── UniversalAIChatService.swift      # Universal AI service
│   └── View/
│       ├── MainView.swift           # Main interface
│       ├── AIChat/                  # AI chat functionality
│       ├── LearnWords/              # Word learning
│       ├── Record/                  # Recording and transcription
│       ├── Settings/                # Settings
│       ├── Shared/                  # Common components
│       └── Transcriptions/          # Transcription management
```

## Features

### Apple Speech Recognition
- Built-in macOS speech recognition engine
- Support for multiple languages and locales
- Real-time mode
- High accuracy for supported languages
- No internet connection required after initial setup

### Transcriptions
- **Session history**: Shows transcriptions from current recording session
- **Persistent history**: All transcriptions saved to JSON files
- **Named recordings**: Save recordings with custom names
- **Export**: Easy access to JSON files through Finder

### AI Integration
- GLM-4-Flash for fast transcription analysis and processing
- Gemini 2.0 Flash for advanced analysis with large context
- Universal AI service for various providers
- AI-powered word learning

## Usage Recommendations

### Audio Settings
- For better quality: use a good USB microphone
- For maximum quality: ensure a quiet environment without echo

### Language Selection
- Choose the language that matches your speech
- Apple Speech works best with languages it was trained for

## Data Storage

All transcriptions are automatically saved to:
- `~/Documents/apple_history.json` - general history
- `~/Documents/apple_history_session.json` - session history
- `~/Documents/Recordings/` - named recordings

## Troubleshooting

### Microphone Issues
1. Check permissions in System Preferences > Security & Privacy > Privacy > Microphone
2. Ensure the microphone is not being used by other applications
3. Try switching the input audio device in System Preferences > Sound > Input

### Recognition Issues
1. Make sure the selected language matches your speech
2. Speak clearly and not too fast
3. Ensure good audio quality (minimal noise)

### AI Chat Setup

To use the AI Chat feature, you'll need an API key from Zhipu AI:

1. Register at [https://open.bigmodel.cn/](https://open.bigmodel.cn/)
2. Get an API key in the API Keys section
3. In the app, click the key icon (🔑) in AI Chat
4. Enter your API key
5. Start chatting with AI!

## License

This project uses the MIT license. See the LICENSE file for details.
