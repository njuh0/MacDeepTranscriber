# WordSorterView Documentation

## Overview

WordSorterView is a sophisticated word sorting interface for the Audio Study app that helps users categorize words from audio transcriptions into three categories: "I Know", "Current Recording", and "Don't Know". The view features advanced text processing capabilities using Apple's Natural Language framework.

## Core Features

### 1. Three-Column Word Organization
- **I Know** (Green): Words the user is familiar with
- **Current Recording** (Blue): Words from the selected transcription that haven't been categorized yet
- **Don't Know** (Red): Words the user wants to learn

### 2. Dual Transcription Support
- **Apple Speech**: Native iOS/macOS speech recognition results
- **AI Enhanced**: AI-processed transcriptions for improved accuracy
- Toggle between sources with a native switch control

### 3. Smart Processing with Apple ML
The most sophisticated feature of WordSorterView is its intelligent word processing powered by Apple's Natural Language framework.

## Smart Processing (Apple ML) - Technical Deep Dive

### Architecture Overview
```
Text Input → NLTokenizer → NLTagger → Lemmatization → Filtering → Word List
```

### Implementation Details

#### 1. Tokenization (`NLTokenizer`)
```swift
let tokenizer = NLTokenizer(unit: .word)
tokenizer.string = text
```
- Breaks down text into individual word tokens
- Handles punctuation, whitespace, and language boundaries
- Respects linguistic word boundaries (important for non-English languages)

#### 2. Linguistic Analysis (`NLTagger`)
```swift
let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
tagger.string = text
```
Two key tagging schemes are used:

**a) Lexical Classification (`.lexicalClass`)**
- Identifies part-of-speech for each word
- Categories: Noun, Verb, Adjective, Adverb, Preposition, Conjunction, etc.
- Only meaningful words are retained: `["Noun", "Verb", "Adjective", "Adverb"]`
- Filters out function words (articles, prepositions, conjunctions)

**b) Lemmatization (`.lemma`)**
- Converts words to their base/dictionary form
- Examples:
  - "running" → "run"
  - "better" → "good" 
  - "children" → "child"
  - "went" → "go"

#### 3. Multi-Language Support
The Natural Language framework automatically:
- Detects the input language
- Applies language-specific rules for tokenization
- Uses appropriate lemmatization dictionaries
- Handles complex morphology (especially important for inflected languages)

#### 4. Quality Filtering
```swift
guard cleanWord.count >= 3,
      !cleanWord.isEmpty,
      !cleanWord.allSatisfy(\.isNumber) else {
    return true
}
```
- Minimum word length: 3 characters
- Excludes pure numbers
- Removes punctuation and whitespace
- Converts to lowercase for consistency

### Smart Processing Algorithm Flow

1. **Input Text Processing**
   ```
   "I was running quickly through the beautiful garden"
   ```

2. **Tokenization**
   ```
   ["I", "was", "running", "quickly", "through", "the", "beautiful", "garden"]
   ```

3. **Lexical Classification & Filtering**
   ```
   "running" → Verb ✓
   "quickly" → Adverb ✓
   "through" → Preposition ✗ (filtered out)
   "the" → Article ✗ (filtered out)
   "beautiful" → Adjective ✓
   "garden" → Noun ✓
   ```

4. **Lemmatization**
   ```
   "running" → "run"
   "quickly" → "quickly" (already base form)
   "beautiful" → "beautiful" (already base form)
   "garden" → "garden" (already base form)
   ```

5. **Final Output**
   ```
   ["run", "quickly", "beautiful", "garden"]
   ```

### Benefits of Smart Processing

#### 1. Vocabulary Consolidation
- Groups related word forms together
- "run", "running", "ran" all become "run"
- Reduces duplicate learning efforts

#### 2. Focus on Learning-Relevant Words
- Excludes function words (articles, prepositions)
- Prioritizes content words (nouns, verbs, adjectives, adverbs)
- Improves vocabulary learning efficiency

#### 3. Language Learning Optimization
- Dictionary lookups become more accurate
- Spaced repetition systems work better with base forms
- Consistent word representation across different contexts

#### 4. Cross-Platform Consistency
- Uses Apple's native ML models
- No internet connection required
- Consistent results across iOS/macOS
- Leverages years of Apple's NLP research

## User Interface Features

### Drag & Drop Functionality
- **From "Current Recording" to "I Know"/"Don't Know"**: Categorizes words
- **From "I Know"/"Don't Know" to "Current Recording"**: Removes categorization
- **Smart Removal Logic**: Words are removed from source even if not present in current transcription

### Settings & Persistence
- **@AppStorage Integration**: User preferences persist between sessions
- **Word Lists**: Known/unknown words saved globally across all recordings
- **Processing Mode**: Smart processing preference remembered
- **Transcription Source**: AI Enhanced vs Apple Speech choice saved

### Visual Feedback
- **Real-time Statistics**: Live count of words in each category
- **Color Coding**: Green (known), Blue (current), Red (unknown)
- **Tooltips**: Helpful explanations for Smart Processing toggle
- **Smooth Animations**: Enhanced user experience with SwiftUI transitions

## Performance Considerations

### Efficiency Optimizations
- **Lazy Processing**: Words processed only when transcription changes
- **Set-based Operations**: Fast word lookup and filtering using Swift Sets
- **Background Processing**: Heavy NL operations don't block UI
- **Incremental Updates**: Only reprocess when necessary

### Memory Management
- **Weak References**: Proper memory management for large texts
- **Tokenizer Reuse**: Single tokenizer instance per processing session
- **Bounded Processing**: Handles large transcriptions efficiently

## Integration with Audio Study App

### Data Flow
```
Audio Recording → Speech Recognition → JSON Storage → WordSorterView → Word Categorization
```

### File Structure Support
- **Apple Speech**: `appleSpeechTranscriptions` array in JSON
- **AI Enhanced**: `aiEnhancedTranscription` string in JSON
- **Dynamic Path Resolution**: No hardcoded user paths

### Cross-Feature Integration
- Shares word lists with other app features
- Integrates with transcription management
- Supports AI enhancement workflow

## Technical Stack

### Apple Frameworks Used
- **Natural Language**: Core ML functionality for text processing
- **SwiftUI**: Modern declarative UI framework
- **Foundation**: File management and data persistence
- **Combine**: Reactive programming for state management

### Key Classes & Protocols
- `NLTokenizer`: Word boundary detection
- `NLTagger`: Linguistic analysis and tagging
- `@AppStorage`: Automatic persistence
- `@State` & `@Binding`: SwiftUI state management

## Future Enhancements

### Potential Improvements
1. **Custom Vocabulary Lists**: User-defined word categories
2. **Difficulty Scoring**: ML-based word difficulty assessment
3. **Context Analysis**: Semantic relationship detection
4. **Multi-language Detection**: Automatic language switching
5. **Export Functionality**: Word lists to Anki, Quizlet, etc.

## Troubleshooting

### Common Issues
1. **Empty Word Lists**: Check if Smart Processing is filtering too aggressively
2. **Slow Performance**: Large transcriptions may need processing optimization
3. **Incorrect Lemmatization**: Apple's NL models may struggle with domain-specific terms
4. **Missing Words**: Verify transcription quality and minimum word length settings

## Conclusion

WordSorterView represents a sophisticated integration of Apple's Machine Learning capabilities with practical language learning needs. The Smart Processing feature leverages years of Apple's Natural Language research to provide an intelligent, efficient, and user-friendly word categorization system that scales across multiple languages and use cases.
