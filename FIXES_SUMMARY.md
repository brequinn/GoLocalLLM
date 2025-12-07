# Bug Fixes Summary

## Issues Fixed

### 1. ✅ Removed "New" Badge from Qwen 3:0.6b
**File**: `Services/MLXService.swift:52`

**Change**:
```swift
// Before
badges: [.init(kind: .new, label: "New")]

// After
badges: []
```

**Reason**: Model is no longer new

---

### 2. ✅ Fixed Auto-Download Issue
**Files**:
- `ViewModels/ChatViewModel.swift:110-156`
- `Views/ChatHomeView.swift:95`

**Problem**: Models were automatically downloading on app launch or when switching models

**Solution**: Added guard checks to only preload models that are already downloaded

**Changes**:
```swift
// preload() now checks if model is downloaded first
guard DownloadedModelsStore.shared.isDownloaded(model.id) else {
    print("⏭️ [ChatVM] Skipping preload for \(model.name) - not downloaded")
    if model.id == selectedModel.id {
        isModelLoaded = false
    }
    return
}
```

**Behavior Now**:
- ✅ App launch: No auto-download
- ✅ Model switch: No auto-download
- ✅ User taps "Download" in ManageModelsView: Download starts
- ✅ User tries to send message with undownloaded model: Download starts (as expected)

---

### 3. ✅ Fixed SettingsView Syntax Error
**File**: `Views/SettingsView.swift:17`

**Problem**: Curly quotes ("") instead of straight quotes ("")

**Change**:
```swift
// Before
Text("Ask a question using your voice with Siri. Activate Siri and say "Hey GoLocalLLM".")

// After
Text("Ask a question using your voice with Siri. Activate Siri and say \"Hey GoLocalLLM\".")
```

**Error Fixed**:
- ❌ "No exact matches in call to initializer"
- ❌ "Expected ',' separator"
- ❌ "Cannot find 'Hey' in scope"

---

### 4. ✅ Fixed MLXService Warning - Unused Result
**File**: `Services/MLXService.swift:162`

**Problem**: Result of `MainActor.run` was unused

**Change**:
```swift
// Before
await MainActor.run {
    if DownloadedModelsStore.shared.isDownloaded(model.id) == false {
        DownloadedModelsStore.shared.markDownloaded(model.id)
    }
}

// After
_ = await MainActor.run {
    if DownloadedModelsStore.shared.isDownloaded(model.id) == false {
        DownloadedModelsStore.shared.markDownloaded(model.id)
    }
}
```

**Warning Fixed**: "Result of call to 'run(resultType:body:)' is unused"

---

### 5. ✅ Fixed String Interpolation Warning
**File**: `Services/MLXService.swift:226`

**Problem**: Optional value interpolated without explicit unwrapping

**Change**:
```swift
// Before
print("... | \(progress.localizedAdditionalDescription)")

// After
print("... | \(progress.localizedAdditionalDescription ?? "N/A")")
```

**Warning Fixed**: "String interpolation produces a debug description for an optional value"

---

## Summary of Changes

| Issue | File | Status |
|-------|------|--------|
| Remove "New" badge | MLXService.swift | ✅ Fixed |
| Auto-download on launch | ChatViewModel.swift | ✅ Fixed |
| Auto-download on switch | ChatViewModel.swift | ✅ Fixed |
| Curly quotes syntax error | SettingsView.swift | ✅ Fixed |
| Unused MainActor.run result | MLXService.swift | ✅ Fixed |
| Optional string interpolation | MLXService.swift | ✅ Fixed |

---

## Testing Checklist

- [ ] App launches without auto-downloading any model
- [ ] Switch between models without triggering downloads
- [ ] Tap "Download" button explicitly starts download
- [ ] Try to send message with undownloaded model triggers download
- [ ] No compiler errors in Xcode
- [ ] No compiler warnings in Xcode
- [ ] Qwen 3:0.6b no longer shows "New" badge

---

## Build Status

All compiler errors and warnings should now be resolved. The app should build successfully.
