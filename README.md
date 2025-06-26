# Audio Study: Your AI-Powered Language Learning & Transcription Companion for macOS

**Transform your Mac into a sophisticated tool for language learning and audio transcription. Audio Study leverages Apple's powerful, on-device Speech Recognition and integrates state-of-the-art AI models to help you master new languages and transcribe audio with unparalleled accuracy.**

![Audio Study App Screenshot](https://user-images.githubusercontent.com/your-image-placeholder.png) 
*A GIF or screenshot of the app in action would be great here!*

---

[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos)
[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## 🚀 Why Audio Study?

Audio Study is more than just a transcription tool. It's a comprehensive ecosystem designed for language learners, students, and professionals who need to work with spoken audio. It combines the best of Apple's native technologies with the power of modern AI, offering a unique, privacy-focused, and highly efficient experience.

- **For Language Learners**: Practice pronunciation, get instant feedback, and build vocabulary lists from any audio source. Use the AI Chat to have conversations and get grammar corrections.
- **For Students & Researchers**: Transcribe lectures, interviews, and research audio with high accuracy. Organize and analyze your transcriptions with AI-powered tools.
- **For Professionals**: Quickly convert meetings, voice notes, and dictations into clean, searchable text.

## ✨ Key Features

- 🎙️ **High-Quality On-Device Transcription**: Utilizes **Apple's native Speech framework** for fast, accurate, and private audio-to-text conversion. No internet connection required for transcription.
- 🌐 **Extensive Language Support**: Supports all languages and locales available through Apple Speech, making it a truly global tool.
- 🧠 **AI-Powered Enhancement & Chat**:
    - **Google Gemini 2.0 Flash**: Leverage Google's latest, powerful AI for advanced text analysis, summarization, and conversation.
    - **Zhipu GLM-4-Flash**: Utilize a fast and efficient model for quick text processing tasks.
    - **Free Tiers**: Both integrated AI models offer generous free tiers, making advanced AI accessible to everyone.
- 📚 **Intelligent Word Sorter**: A unique tool for language learners that uses **Apple's Natural Language framework** to:
    - **Lemmatize words** (e.g., "running", "ran" -> "run").
    - Filter for meaningful vocabulary (nouns, verbs, adjectives).
    - Categorize words into "Known" and "Unknown" lists to track your learning progress.
- 🗂️ **Advanced Transcription Management**:
    - **Session History**: Automatically saves all transcriptions.
    - **Named Recordings**: Save and organize your sessions with custom titles.
    - **AI Enhancement**: Clean up and correct transcription errors with a single click.
    - **Export**: Easily export your data to JSON for use in other applications.
- 🔒 **Privacy First**: All transcriptions and audio processing are done on-device. Your API keys are stored securely in the local keychain. Your data remains yours.
- 💻 **Built with SwiftUI**: A modern, clean, and responsive user interface built entirely with SwiftUI.

## 🛠️ Technology Stack

- **UI**: SwiftUI
- **Core Logic**: Swift
- **Speech Recognition**: Apple Speech Framework
- **Natural Language Processing**: Apple Natural Language Framework
- **AI Integration**: REST API integration with Google AI (Gemini) and Zhipu AI (GLM)
- **Dependencies**: 100% native Apple frameworks. No external dependencies.

## 🚀 Getting Started

### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- An Apple Developer account (for running on a device)

### Installation & Running

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/Audio-Study.git
    cd Audio-Study
    ```

2.  **Open the project in Xcode:**
    ```bash
    open "Audio Study.xcodeproj"
    ```

3.  **Configure Signing & Capabilities:**
    - In Xcode, select the `Audio Study` project in the navigator.
    - Go to the `Signing & Capabilities` tab.
    - Select your developer team.

4.  **Run the project:**
    - Press `Cmd+R` to build and run the application on your Mac.

### API Key Configuration

To use the AI-powered features, you'll need to obtain free API keys from the respective providers.

1.  **Navigate to Settings**: Open the app and go to the `Settings` (⚙️) tab.
2.  **Select an AI Model**: Choose either `Gemini 2.0 Flash` or `GLM-4-Flash`.
3.  **Get API Key**:
    - For **Google Gemini**: Click the "Get API Key" link or visit [Google AI Studio](https://aistudio.google.com/app/apikey).
    - For **Zhipu GLM**: Click the "Get API Key" link or visit [open.bigmodel.cn](https://open.bigmodel.cn/).
4.  **Enter and Save**: Paste your API key into the input field and click "Save".

## 📂 Project Structure

The project is organized into a clean, modular structure to make it easy to navigate and contribute.

```
Audio Study/
├── Audio Study/
│   ├── Audio_StudyApp.swift         # App entry point
│   ├── Model/                       # Data models (Transcription, AI, Navigation)
│   ├── Service/                     # Business logic (Audio Capture, Speech Recognition, AI Services)
│   └── View/                        # SwiftUI Views
│       ├── MainView.swift           # Main navigation structure
│       ├── Record/                  # Recording and transcription UI
│       ├── Transcriptions/          # Saved recordings browser
│       ├── WordSorter/              # Language learning word sorter UI
│       ├── AIChat/                  # AI chat interface
│       ├── Settings/                # App settings and API key configuration
│       └── Shared/                  # Reusable UI components
```

## 🤝 Contributing

Contributions are welcome! Whether it's a bug report, a feature request, or a pull request, your input is valued. Please feel free to open an issue to discuss your ideas.

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/YourFeature`).
3.  Commit your changes (`git commit -m 'Add some feature'`).
4.  Push to the branch (`git push origin feature/YourFeature`).
5.  Open a Pull Request.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.