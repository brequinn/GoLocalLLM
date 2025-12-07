# Reasoning Display Toggle Feature

## Overview
You now have full control over whether to see the model's thinking process! Users can toggle between seeing detailed reasoning or just a compact thinking animation.

---

## 🎛️ What Was Added

### 1. **App Settings Manager** (`Support/AppSettings.swift`)

A new settings system that persists user preferences:

```swift
@Observable
class AppSettings {
    static let shared = AppSettings.shared
    var showModelReasoning: Bool  // Default: true
}
```

- Stores preference in `UserDefaults`
- Survives app restarts
- Observable for real-time UI updates

---

### 2. **Settings Toggle** (`Views/SettingsView.swift`)

New **"Display"** section in Settings with a toggle:

```
┌─ Display ─────────────────────────┐
│ ☑ Show Model Reasoning           │
│   Display the model's thinking    │
│   process in reasoning bubbles    │
└───────────────────────────────────┘
```

**Location**: Settings → Display → Show Model Reasoning

**Default**: ON (enabled)

---

### 3. **Conditional Rendering** (`Views/MessageView.swift`)

Messages now check the setting before showing reasoning:

#### **When Enabled (Default)**
Shows full reasoning bubble with:
- 💡 Lightbulb icon with amber gradient
- "Model thoughts" or "Thinking..." label
- Full reasoning text in monospaced font
- Warm amber border and background

#### **When Disabled**
Shows compact indicator with:
- ⚪⚪⚪ Three animated dots
- "Thinking..." or "Thought about this" label
- Minimal space usage
- Same amber accent color

---

## 🎨 Visual Comparison

### Reasoning Enabled (Default)
```
┌────────────────────────────────────┐
│ 💡 Model thoughts                 │
│                                    │
│ The user is asking about...       │
│ I should consider...               │
│ The best approach would be...     │
└────────────────────────────────────┘

Hello! I'd be happy to help with that.
```

### Reasoning Disabled
```
⚪⚪⚪ Thought about this

Hello! I'd be happy to help with that.
```

---

## 🔧 How It Works

### User Flow
1. User goes to **Settings**
2. Taps **"Display"** section
3. Toggles **"Show Model Reasoning"** ON or OFF
4. Setting saves immediately
5. All current and future messages respect the setting

### Technical Flow
```
Message arrives with reasoning
        ↓
MessageView checks AppSettings.shared.showModelReasoning
        ↓
   ┌────┴────┐
   ↓         ↓
 TRUE      FALSE
   ↓         ↓
Full      Compact
Bubble    Indicator
```

---

## 🎯 Use Cases

### When to Enable (Show Full Reasoning)
✅ **Learning how models think** - Educational purposes
✅ **Debugging model behavior** - Understanding responses
✅ **Transparency** - Seeing the decision-making process
✅ **Prompt engineering** - Optimizing prompts based on reasoning

### When to Disable (Compact Mode)
✅ **Cleaner interface** - Less visual clutter
✅ **Faster reading** - Focus on final answers only
✅ **Casual chatting** - Don't need to see the process
✅ **Limited screen space** - Mobile devices

---

## 📊 Models That Support Reasoning

Only certain models emit `<think>` tags with reasoning:

**Models with Reasoning**:
- ✅ **Qwen 2.5:1.5b** 🐼 (Badge: "Thinking")
- ✅ **Qwen 3:4b** 🧠 (Badge: "Thinking")

**Models without Reasoning**:
- ❌ Llama 3.2:1b
- ❌ Qwen 3:0.6b
- ❌ Qwen 2 VL:2b (vision model)

If a model doesn't emit reasoning, neither indicator will show.

---

## 🎨 Design Details

### Compact Thinking Indicator

**Visual Elements**:
- Three amber gradient dots
- Staggered animation (0.2s delay between dots)
- Scale animation: 1.0 → 1.3
- Duration: 0.6s ease-in-out loop

**Colors**:
- Dots: Amber gradient `rgb(230, 153, 51)` → `rgb(255, 179, 77)`
- Background: Warm cream `rgba(250, 242, 230, 0.3)`
- Border: Amber `rgba(230, 153, 51, 0.2)`

**Typography**:
- Font: 12pt SF Rounded Medium
- Text: "Thinking..." (streaming) or "Thought about this" (complete)

**Size**:
- Height: ~32px (vs ~80-150px for full bubble)
- Width: Auto-fit content (~120px)

---

## 💾 Persistence

### Storage
```swift
UserDefaults.standard.set(showModelReasoning, forKey: "showModelReasoning")
```

### Default Value
```swift
// First install or missing key = true (show reasoning)
self.showModelReasoning = UserDefaults.standard.object(forKey: showReasoningKey) as? Bool ?? true
```

### App Lifecycle
1. **First Launch**: Setting defaults to `true`
2. **User Changes**: Saves immediately to UserDefaults
3. **App Restart**: Loads saved preference
4. **App Update**: Preserves user's choice

---

## 🔄 Dynamic Updates

Settings changes apply **immediately** without needing to:
- ❌ Restart the app
- ❌ Reload the view
- ❌ Clear messages

**Real-time Update**:
```swift
@State private var settings = AppSettings.shared  // Observable
```

SwiftUI automatically re-renders when `showModelReasoning` changes.

---

## 🧪 Testing

### Test Cases

1. **Enable/Disable Toggle**
   - Open Settings
   - Toggle "Show Model Reasoning" OFF
   - Ask Qwen 2.5 a question
   - Should see compact indicator only

2. **Persistence**
   - Toggle setting OFF
   - Force quit app
   - Reopen app
   - Setting should still be OFF

3. **Real-time Update**
   - Ask Qwen 2.5 a question (with reasoning enabled)
   - While response is streaming, toggle setting OFF
   - Existing messages stay unchanged
   - New messages use compact mode

4. **Model Compatibility**
   - Switch to Llama 3.2 (no reasoning)
   - No indicators should show (neither full nor compact)
   - Switch to Qwen 2.5 (reasoning)
   - Appropriate indicator should appear

---

## 📝 Future Enhancements

Possible improvements:
- [ ] Add gesture to expand/collapse reasoning inline
- [ ] Show reasoning only on tap/hold (hide by default)
- [ ] Add "Auto" mode (show for long reasoning, hide for short)
- [ ] Per-model reasoning preferences
- [ ] Export reasoning separately
- [ ] Syntax highlighting for reasoning text

---

## 🐛 Troubleshooting

### Setting Doesn't Persist
- Check UserDefaults isn't corrupted
- Verify key matches: `"showModelReasoning"`
- Try deleting and reinstalling app

### Toggle Doesn't Change Display
- Verify AppSettings.shared is Observable
- Check MessageView is using `private let settings = AppSettings.shared`
- Ensure SwiftUI is observing changes

### Compact Indicator Not Animating
- Check device performance mode
- Verify animation isn't disabled system-wide
- Reduce motion accessibility setting may affect this

---

## 🎯 Design Decisions

### Why Default to ON?
- **Transparency**: Shows model's thinking process
- **Educational**: Helps users understand AI
- **Trust**: Builds confidence in responses
- **Opt-out**: Users who want cleaner UI can disable

### Why Compact Mode (Not Hide Completely)?
- **Awareness**: User knows reasoning happened
- **Consistency**: Visual indicator keeps flow
- **Discovery**: Reminds users the feature exists
- **Debugging**: Can tell if reasoning is working

### Why Not Collapsible?
- **Simplicity**: Binary choice is clearer
- **Performance**: Fewer state transitions
- **UX**: Predictable behavior
- **Future**: Can add later if needed

---

## 📄 Files Modified

1. **NEW**: `Support/AppSettings.swift` - Preference management
2. **MODIFIED**: `Views/SettingsView.swift` - Added Display section with toggle
3. **MODIFIED**: `Views/MessageView.swift` - Conditional rendering + CompactThinkingIndicator

---

## ✨ Summary

You now have:
- 🎛️ **User control** over reasoning display
- 📱 **Cleaner UI option** for casual use
- 🔍 **Full transparency option** for power users
- 💾 **Persistent preference** across app restarts
- 🎨 **Polished compact mode** with animated dots
- ⚡ **Real-time updates** when toggling

Perfect balance between transparency and simplicity! 🚀
