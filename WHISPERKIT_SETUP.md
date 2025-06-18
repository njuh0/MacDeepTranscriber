# WhisperKit Setup Instructions

## Adding WhisperKit to Xcode Project

WhisperKit is a native Swift implementation of OpenAI's Whisper model, optimized for Apple Silicon.

### Step 1: Add Package Dependency in Xcode

1. Open `Audio Study.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "Audio Study")
3. Select the "Audio Study" target
4. Go to the "Package Dependencies" tab
5. Click the "+" button to add a new package
6. Enter the URL: `https://github.com/argmaxinc/WhisperKit.git`
7. Choose "Up to Next Major Version" with version 0.7.0
8. Click "Add Package"
9. Select "WhisperKit" and click "Add Package"

### Step 2: Update WhisperKitService.swift

After adding the package dependency, uncomment the WhisperKit import and implementation:

1. **Uncomment the import:**
   ```swift
   import WhisperKit
   ```

2. **Uncomment the whisperKit property:**
   ```swift
   private var whisperKit: WhisperKit?
   ```

3. **Replace the simulation methods with actual WhisperKit calls:**
   - Uncomment the real `loadWhisperModel()` implementation
   - Uncomment the real `transcribeAudioData()` implementation
   - Remove or comment out the simulation methods

### Step 3: Enable Required Capabilities

Make sure the following are enabled in your project:

1. **App Sandbox** (if using sandbox)
   - Incoming Connections (Client)
   - Outgoing Connections (Client) 
   - Hardware: Audio Input

2. **Hardened Runtime** 
   - Audio Input
   - Network (for model downloads)

### Step 4: Update Info.plist

Ensure these usage descriptions are in your Info.plist:
- `NSMicrophoneUsageDescription`
- `NSNetworkUsageDescription` (for model downloads)

## WhisperKit Models

WhisperKit supports these models:
- `openai/whisper-tiny` (39 MB) - Fastest, least accurate
- `openai/whisper-tiny.en` (39 MB) - English-only tiny model
- `openai/whisper-base` (74 MB) - Good balance
- `openai/whisper-base.en` (74 MB) - English-only base model
- `openai/whisper-small` (244 MB) - Better accuracy
- `openai/whisper-small.en` (244 MB) - English-only small model
- `openai/whisper-medium` (769 MB) - High accuracy
- `openai/whisper-medium.en` (769 MB) - English-only medium model
- `openai/whisper-large-v2` (1550 MB) - Best accuracy
- `openai/whisper-large-v3` (1550 MB) - Latest large model

Models are downloaded automatically on first use and cached locally.

## Implementation Status

### Current Status
- ✅ Complete WhisperKit service structure
- ✅ Audio buffer management
- ✅ Periodic transcription
- ✅ UI integration with progress indicators
- ✅ Model loading progress tracking
- ⏳ Actual WhisperKit integration (requires package dependency)

### Next Steps
1. Add WhisperKit package dependency in Xcode
2. Uncomment WhisperKit code in `WhisperKitService.swift`
3. Replace simulation methods with actual WhisperKit calls
4. Test with different model sizes

## Performance Considerations

### Model Performance (on Apple Silicon)
- **tiny**: ~100ms transcription time, basic accuracy
- **base**: ~200ms transcription time, good accuracy  
- **small**: ~500ms transcription time, better accuracy
- **medium**: ~1-2s transcription time, high accuracy
- **large**: ~2-3s transcription time, best accuracy

### Memory Usage
- **tiny**: ~100MB RAM
- **base**: ~200MB RAM
- **small**: ~500MB RAM
- **medium**: ~1GB RAM
- **large**: ~2GB RAM

### Recommendations
- For real-time use: Use Apple Speech Recognition
- For good quality offline: Use `whisper-tiny` or `whisper-base`
- For best quality: Use `whisper-small` or `whisper-medium`
- English-only models (.en) are faster for English content

## Code Changes Required

### 1. Uncomment WhisperKit Import
```swift
// Change this:
// import WhisperKit

// To this:
import WhisperKit
```

### 2. Uncomment WhisperKit Property
```swift
// Change this:
// private var whisperKit: WhisperKit?

// To this:
private var whisperKit: WhisperKit?
```

### 3. Replace loadWhisperModel Implementation
Replace the simulation with the commented real implementation.

### 4. Replace transcribeAudioData Implementation
Replace the simulation with the commented real implementation.

## Troubleshooting

### Model Download Issues
- Ensure internet connection for first-time model download
- Models are cached in `~/Library/Caches/WhisperKit/`
- Clear cache if models become corrupted: `rm -rf ~/Library/Caches/WhisperKit/`

### Performance Issues
- Use smaller models for real-time transcription
- Adjust `transcriptionInterval` in WhisperKitService (default: 3s)
- Monitor memory usage with larger models
- Consider using English-only models for English content

### Audio Issues
- Verify BlackHole is properly configured
- Check microphone permissions in System Settings
- Monitor Console.app for detailed error logs

### Build Issues
- Ensure Xcode 15+ for WhisperKit compatibility
- Verify deployment target is macOS 13+ or iOS 16+
- Check that WhisperKit package was added correctly

## Example Usage

```swift
// Initialize with different model
let whisperService = WhisperKitService(modelName: "openai/whisper-base")

// Switch models at runtime
whisperService.switchModel(to: "openai/whisper-small")

// Get available models
let models = WhisperKitService.availableModels()

// Get model info
let (size, description) = WhisperKitService.modelInfo(for: "openai/whisper-tiny")
```

## Benefits of WhisperKit

1. **Native Swift**: No Python dependencies
2. **Apple Silicon Optimized**: Uses Metal Performance Shaders
3. **Offline**: Works without internet after model download
4. **High Quality**: Same accuracy as OpenAI Whisper
5. **Easy Integration**: Standard Swift Package Manager
6. **Memory Efficient**: Optimized for mobile/desktop use