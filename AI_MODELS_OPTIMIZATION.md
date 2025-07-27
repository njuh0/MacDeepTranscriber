# AI Models Optimization - MacDeepTranscriber

## 🎯 Optimization Goal
Simplifying the codebase by reducing the number of supported AI models from 4 to 2 most efficient ones.

## ✂️ Removed Models
- **GLM-4** - replaced with GLM-4-Flash (faster version)
- **ChatGLM3-6B** - outdated model, less efficient

## ✅ Remaining Models
1. **GLM-4-Flash** ⚡
   - Provider: Zhipu AI (智谱AI)
   - Speed: Very high
   - Context: 8,192 tokens
   - Max output: 4,095 tokens
   - Free plan: 1M tokens/month

2. **Gemini 2.0 Flash** 🚀
   - Provider: Google AI
   - Speed: Very high
   - Context: 1,000,000 tokens
   - Max output: 8,192 tokens
   - Free plan: 1,500 requests/day

## 🔧 Technical Changes

### Files modified:
- `AIModel.swift` - removed extra enum cases
- `UniversalAIChatService.swift` - simplified limit functions
- `GLMChatService.swift` - simplified limit functions
- `TranscriptionsView.swift` - optimized limit functions and logging
- Documentation (README.md, AI_SETTINGS_GUIDE.md, GEMINI_INTEGRATION.md)

### Simplified functions:
```swift
// Before:
switch model.displayName {
    case "GLM-4": return 4095
    case "GLM-4-Flash": return 4095  
    case "ChatGLM3-6B": return 4095
    case "Gemini 2.0 Flash": return 8192
    default: // complex fallback logic
}

// After:
switch model {
    case .glm4Flash: return 4095
    case .gemini2Flash: return 8192
}
```

## 📊 Optimization Benefits

1. **Code simplification**: Fewer conditions and branches
2. **Easier maintenance**: Focus on 2 best models
3. **Faster development**: Fewer test scenarios
4. **Better UX**: Users choose from the best options
5. **Relevance**: Only modern models

## 🎯 Usage Recommendations

### For users:
- **GLM-4-Flash**: For fast processing of short texts
- **Gemini 2.0 Flash**: For complex tasks with large texts

### For developers:
- When adding new models, add them to the `AIModel` enum
- Update limit functions for each new model
- Document capabilities and limitations in README

## 🔄 Migration for users
Users who used removed models:
- GLM-4 → will automatically switch to GLM-4-Flash
- ChatGLM3-6B → will automatically switch to GLM-4-Flash

API key settings remain unchanged.
