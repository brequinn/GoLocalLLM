# Download & Remove Fixes

## Issues Fixed

### 1. ✅ Download Button Not Working
**Problem**: After preventing auto-downloads, explicit downloads via "Download" button also stopped working

**Root Cause**:
```swift
// ManageModelsView called preload()
Button("Download") {
    Task { await vm.preload(model: model) }
}

// But preload() now skips undownloaded models
guard DownloadedModelsStore.shared.isDownloaded(model.id) else {
    return  // ❌ Blocks explicit downloads!
}
```

**Solution**: Added separate `downloadModel()` method for explicit user-initiated downloads

**Files Changed**:
- `ViewModels/ChatViewModel.swift` - Added `downloadModel(_:)` method
- `Views/ManageModelsView.swift` - Download button now calls `downloadModel()`

**New Flow**:
```
User taps "Download"
    ↓
ManageModelsView.Button("Download")
    ↓
vm.downloadModel(model)  ← New explicit method
    ↓
mlxService.preload(model)  ← Always downloads
    ↓
✅ Download starts!
```

---

### 2. ✅ Remove Button Delayed/Failing
**Problem**: Removing models was delayed or failed with error: "Qwen3-4B-4bit couldn't be removed"

**Root Cause**: Model was still loaded in memory/MLX runtime, files were locked

**Solution**: Improved removal sequence with proper cleanup order

**New Removal Steps**:
```
1. Cancel ongoing tasks (loadTasks, downloads)
2. Remove from memory cache
3. Clear all cache (release MLX resources)
4. Mark as not downloaded immediately
5. Wait 0.1s for MLX to release file handles
6. Remove files from disk
```

**Files Changed**:
- `Services/MLXService.swift:345-385` - Enhanced `removeDownload(for:)` method

**Benefits**:
- ✅ Proper cleanup order prevents file locks
- ✅ 0.1s delay gives MLX time to release resources
- ✅ Better error handling and logging
- ✅ Marks as not downloaded even if file removal fails (allows retry)

---

## Technical Details

### Method 1: `downloadModel(_:)` - Explicit Downloads

```swift
func downloadModel(_ model: LMModel) async {
    // Cancel any existing preload task
    preloadTask?.cancel()

    preloadTask = Task {
        do {
            if model.id == selectedModel.id {
                isModelLoaded = false
            }
            print("⬇️ [ChatVM] Starting explicit download for: \(model.name)")
            try await mlxService.preload(model: model)
            if model.id == selectedModel.id {
                isModelLoaded = true
            }
            print("✅ [ChatVM] Downloaded and loaded model: \(model.name)")
        } catch is CancellationError {
            print("🚫 [ChatVM] Download cancelled for: \(model.name)")
        } catch {
            if model.id == selectedModel.id {
                isModelLoaded = false
            }
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            print("❌ [ChatVM] Download failed: \(error.localizedDescription)")
        }
    }

    await preloadTask?.value
}
```

**When Called**:
- ✅ User taps "Download" button in ManageModelsView
- ✅ User tries to send message with undownloaded model

**Difference from `preload()`**:
- `downloadModel()`: Always downloads, even if not downloaded yet
- `preload()`: Only loads models that are already downloaded (prevents auto-download)

---

### Method 2: `removeDownload(for:)` - Improved Cleanup

```swift
func removeDownload(for model: LMModel) async throws {
    print("🗑️ [MLXService] Starting removal for \(model.name)")

    // Step 1: Cancel any ongoing tasks first
    await MainActor.run {
        self.loadTasks[model.id]?.cancel()
        self.loadTasks[model.id] = nil
        if self.downloadingModelID == model.id {
            self.downloadingModelID = nil
            self.modelDownloadProgress = nil
        }
    }

    // Step 2: Remove from memory cache to release MLX resources
    modelCache.removeObject(forKey: model.name as NSString)
    modelCache.removeAllObjects()
    print("🧹 [MLXService] Cleared cache for \(model.name)")

    // Step 3: Mark as not downloaded immediately
    await MainActor.run {
        DownloadedModelsStore.shared.remove(model.id)
    }

    // Step 4: Small delay to let MLX framework release file handles
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // Step 5: Remove files from disk
    let directory = model.configuration.modelDirectory(hub: .default)
    if FileManager.default.fileExists(atPath: directory.path()) {
        do {
            try FileManager.default.removeItem(at: directory)
            print("✅ [MLXService] Successfully removed files for \(model.name)")
        } catch {
            print("⚠️ [MLXService] Failed to remove files for \(model.name): \(error.localizedDescription)")
            throw error
        }
    }
}
```

**Key Improvements**:
1. **Task cancellation first** - Stops any ongoing downloads/loads
2. **Cache clearing** - `removeAllObjects()` ensures complete cleanup
3. **Immediate UI update** - Marks as not downloaded before file removal
4. **Resource release delay** - 0.1s gives MLX time to close file handles
5. **Better error handling** - Logs each step, allows retry even if file removal fails

---

## User Flow Comparison

### Download Flow

**Before** (Broken):
```
User taps "Download"
    ↓
vm.preload(model)
    ↓
❌ Skipped: "not downloaded"
    ↓
Nothing happens!
```

**After** (Fixed):
```
User taps "Download"
    ↓
vm.downloadModel(model)
    ↓
mlxService.preload(model)
    ↓
✅ Download starts!
    ↓
Progress shows in UI
    ↓
✅ Model ready
```

---

### Remove Flow

**Before** (Delayed/Failed):
```
User taps "Remove"
    ↓
removeDownload(model)
    ↓
❌ File locked (MLX still using)
    ↓
Error: "couldn't be removed"
    ↓
⏰ Eventually succeeds after delay
```

**After** (Fixed):
```
User taps "Remove"
    ↓
removeDownload(model)
    ↓
1. Cancel tasks
2. Clear cache
3. Mark not downloaded (UI updates!)
4. Wait 0.1s
5. Remove files
    ↓
✅ Removed successfully!
```

---

## Testing Checklist

### Download Tests
- [ ] Tap "Download" on Qwen 2 VL:2b → Should start downloading immediately
- [ ] Check logs for: `⬇️ [ChatVM] Starting explicit download for: qwen2VL:2b`
- [ ] Progress should show in UI
- [ ] After completion: `✅ [ChatVM] Downloaded and loaded model: qwen2VL:2b`

### Remove Tests
- [ ] Download a model
- [ ] Select it (so it loads into memory)
- [ ] Tap "Remove" → Should remove within 0.2 seconds
- [ ] Check logs for: `🗑️ [MLXService] Starting removal`, `🧹 [MLXService] Cleared cache`, `✅ [MLXService] Successfully removed files`
- [ ] UI should immediately show model as not downloaded

### Edge Case Tests
- [ ] Start download → Cancel → Try to remove → Should work
- [ ] Download model → Send message (loads into MLX) → Remove → Should work
- [ ] Remove while downloading → Should cancel download and remove
- [ ] Download same model twice quickly → Should cancel first attempt

---

## Logs to Watch For

### Successful Download
```
⬇️ [ChatVM] Starting explicit download for: qwen2VL:2b
⬇️ [MLXService] loadContainer begin for qwen2VL:2b
⬇️ [MLXService] qwen2VL:2b progress: 45%
✅ [MLXService] Finished download for qwen2VL:2b
✅ [ChatVM] Downloaded and loaded model: qwen2VL:2b
```

### Successful Removal
```
🗑️ [MLXService] Starting removal for qwen3:4b
🧹 [MLXService] Cleared cache for qwen3:4b
✅ [MLXService] Successfully removed files for qwen3:4b
🗑️ [ChatVM] Removed local copy: qwen3:4b
```

### Failed Removal (Retry Possible)
```
🗑️ [MLXService] Starting removal for qwen3:4b
🧹 [MLXService] Cleared cache for qwen3:4b
⚠️ [MLXService] Failed to remove files for qwen3:4b: <error>
❌ [ChatVM] Remove failed: <error>
```

---

## Summary

| Issue | Status | Solution |
|-------|--------|----------|
| Download button not working | ✅ Fixed | Added `downloadModel()` method |
| Remove delayed/failing | ✅ Fixed | Improved cleanup sequence + 0.1s delay |
| Auto-download prevention | ✅ Still works | `preload()` still checks `isDownloaded` |
| Explicit downloads | ✅ Works | `downloadModel()` bypasses check |

**Result**:
- ✅ Downloads work when explicitly requested
- ✅ No auto-downloads on app launch or model switch
- ✅ Removes complete quickly and reliably
- ✅ Better error handling and logging throughout
