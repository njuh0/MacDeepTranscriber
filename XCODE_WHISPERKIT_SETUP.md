# Правильная настройка WhisperKit в Xcode

## Проблема
Если вы получаете ошибку "No such module 'WhisperKit'", это означает, что пакет не был правильно добавлен в Xcode проект.

## Решение: Добавление WhisperKit через Xcode

### Шаг 1: Откройте проект в Xcode
1. Откройте `Audio Study.xcodeproj` (НЕ Package.swift)
2. Убедитесь, что вы работаете с .xcodeproj файлом

### Шаг 2: Добавьте Package Dependency
1. В Xcode выберите проект "Audio Study" в навигаторе (самый верхний элемент)
2. Выберите target "Audio Study" 
3. Перейдите на вкладку **"Package Dependencies"**
4. Нажмите кнопку **"+"** внизу списка
5. В поле URL введите: `https://github.com/argmaxinc/WhisperKit.git`
6. Нажмите **"Add Package"**
7. Выберите **"Up to Next Major Version"** и версию **0.7.0**
8. Нажмите **"Add Package"**
9. В списке продуктов выберите **"WhisperKit"**
10. Нажмите **"Add Package"**

### Шаг 3: Проверьте добавление
1. В навигаторе проекта должна появиться секция "Package Dependencies"
2. В ней должен быть "WhisperKit"
3. Если его нет, повторите шаги выше

### Шаг 4: Активируйте WhisperKit в коде
После успешного добавления пакета:

1. **Раскомментируйте импорт в WhisperKitService.swift:**
   ```swift
   // Измените это:
   // import WhisperKit
   
   // На это:
   import WhisperKit
   ```

2. **Раскомментируйте свойство whisperKit:**
   ```swift
   // Измените это:
   // private var whisperKit: WhisperKit?
   
   // На это:
   private var whisperKit: WhisperKit?
   ```

3. **Замените симуляцию на реальную реализацию:**
   - В методе `loadWhisperModel()` закомментируйте `await simulateModelLoading()`
   - Раскомментируйте блок с реальной инициализацией WhisperKit
   - В методе `transcribeAudioData()` закомментируйте симуляцию
   - Раскомментируйте блок с реальной транскрипцией

### Шаг 5: Обновите код для правильного API WhisperKit

Замените инициализацию WhisperKit на правильную:

```swift
// В методе loadWhisperModel() замените на:
whisperKit = try await WhisperKit(
    model: modelName,
    downloadBase: URL.documentsDirectory,
    modelRepo: nil,
    modelFolder: nil,
    tokenizerFolder: nil,
    computeUnits: .all,
    audioProcessor: nil,
    featureExtractor: nil,
    audioEncoder: nil,
    textDecoder: nil,
    logLevel: .info,
    prewarm: false,
    load: true,
    download: true
) { progress in
    DispatchQueue.main.async {
        self.modelLoadingProgress = progress.fractionCompleted
    }
}
```

## Альтернативное решение: Использование симуляции

Если у вас проблемы с добавлением пакета, вы можете использовать текущую симуляцию:

1. Оставьте `// import WhisperKit` закомментированным
2. Оставьте `// private var whisperKit: WhisperKit?` закомментированным
3. Используйте симуляцию для тестирования UI

## Проверка работы

После правильной настройки:

1. Проект должен компилироваться без ошибок
2. При запуске приложения должна появиться полоса загрузки модели
3. После загрузки статус должен показать "Available"
4. При выборе WhisperKit и нажатии "Start Capture" должна начаться транскрипция

## Устранение проблем

### Ошибка "No such module 'WhisperKit'"
- Убедитесь, что пакет добавлен в правильный target
- Попробуйте очистить build folder: Product → Clean Build Folder
- Перезапустите Xcode

### Ошибка "Cannot find type 'WhisperKit'"
- Проверьте, что импорт раскомментирован
- Убедитесь, что пакет правильно добавлен

### Ошибки компиляции в API
- Проверьте версию WhisperKit (должна быть 0.7.0+)
- API может отличаться в разных версиях

## Рекомендуемый порядок действий

1. **Сначала протестируйте с симуляцией** - убедитесь, что UI работает
2. **Добавьте пакет WhisperKit** через Xcode
3. **Постепенно активируйте реальный код** - сначала импорт, потом инициализацию
4. **Тестируйте на каждом шаге** - убедитесь, что нет ошибок компиляции

Это позволит вам поэтапно перейти от симуляции к реальной работе с WhisperKit.