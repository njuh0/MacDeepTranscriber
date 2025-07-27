# View Structure Organization

After reorganization, the View files are now organized by functional groups:

## 📁 Audio Study/View/

### 🎙️ Record/
Files related to audio recording and transcription:
- `RecordView.swift` - main recording screen
- `ControlsView.swift` - recording control elements
- `TranscriptionOutputView.swift` - transcription results display
- `TranscriptionHistoryView.swift` - transcription history

### 📚 LearnWords/
Files for word learning:
- `LearnWordsView.swift` - main word learning screen

### 🤖 AIChat/
Files for AI chat:
- `AIChatView.swift` - main AI chat screen

### ⚙️ Settings/
Settings files:
- `SettingsView.swift` - main settings screen
- `LanguageSelectionView.swift` - language selection for Apple Speech

### 🔄 Shared/
Common components used across different screens:
- `ErrorBannerView.swift` - error banner

### 🏠 Root files
- `MainView.swift` - main window with navigation

## Advantages of the new structure:

1. **Logical grouping** - files are grouped by functionality
2. **Easy navigation** - easier to find the needed file
3. **Scalability** - easy to add new files to appropriate folders
4. **Team collaboration** - different developers can work with different modules
5. **Maintenance** - easier to localize changes and fixes

