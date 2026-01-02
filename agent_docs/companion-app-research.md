# Companion App Research

## Reference Implementation: Aerial Companion

**Source:** `github.com/AerialScreensaver/AerialCompanion`

Aerial solved the macOS Catalina sandbox problem with a companion app architecture. This document captures patterns to apply to Electric Sheep.

## Architecture Pattern

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Companion App          │     │  Screensaver            │
│  (Menu bar, full access)│────▶│  (Display only)         │
└─────────────────────────┘     └─────────────────────────┘
         │
         ▼
  ~/Library/Application Support/{AppName}/
```

## Aerial Companion Features

### 1. Menu Bar Presence
- NSStatusItem with dropdown menu
- Options: Check Now, Update Mode, Launch Mode, Quit
- Can run in background (no menu icon)

### 2. Update Management
- Manifest JSON: version number + SHA256 hashes
- Download to `~/Library/Application Support/AerialUpdater/`
- Verify SHA256 before install
- Verify codesigning (bundle ID + developer ID)
- Copy `.saver` to `~/Library/Screen Savers/`

### 3. Frequency Options
- Hourly, Daily, Weekly, Manual
- Automatic or notification-based updates

### 4. Background Mode
- Launch agent for headless operation
- No status bar icon required

## Why Companion App?

### The Catalina Problem
Apple sandboxed third-party screensavers in macOS 10.15:
- Screensavers run in `legacyScreenSaver.appex` container
- Network access blocked
- Filesystem writes restricted
- Keyboard input may be blocked

### Failed Workarounds
1. **Sparkle in screensaver** - Caused ScreenSaverEngine to lose keyboard focus
2. **Notification only** - Required manual download/install
3. **XPC from screensaver** - Sandbox prevents outbound connections

### The Solution
Separate app running outside sandbox handles:
- Network operations (downloads)
- Filesystem writes (cache)
- Background tasks (updates)

Screensaver becomes read-only display component.

## Electric Sheep Companion Design

### Required Features
1. **Sheep Downloading**
   - Fetch sheep list from `sheepserver.net`
   - Download videos to shared cache
   - Progress tracking in menu bar

2. **Voting**
   - Capture hotkeys (companion has keyboard access)
   - Submit votes to server
   - Queue votes when offline

3. **Gold Authentication**
   - Keychain credential storage
   - Token refresh
   - Premium content access

4. **Distributed Rendering** (optional)
   - Receive render jobs
   - Execute flam3 renderer
   - Upload completed frames

### Shared Cache Location
```
~/Library/Application Support/ElectricSheep/
├── sheep/
│   ├── free/           # Free sheep (gen 0-9999)
│   └── gold/           # Gold sheep (gen 10000+)
├── downloads/          # In-progress (.tmp files)
├── metadata/           # Sheep metadata JSON
├── lists/              # Cached server XML
├── playback.json       # LRU tracking
├── config.json         # User preferences
└── offline_votes.json  # Queued offline votes
```

**Note:** Legacy client used `mpeg/` and `xml/`. Companion app uses new structure above.

### IPC Method: Distributed Notifications

**Chosen approach: CFNotificationCenter (9 notifications)**
- Real-time, no polling required
- Works across sandbox boundaries
- Payloads encoded as notification name suffix
- See `plans/phase-4-ipc-communication.md` for protocol details

## Implementation Language

### Swift Advantages
- Modern macOS APIs (SwiftUI, Combine)
- Better Keychain integration
- Native URLSession networking
- Easier menu bar app development

### Bridge Considerations
- Can call existing C++ code via Objective-C++ bridge
- Alternatively, reimplement networking in Swift
- Recommend: New Swift networking, reuse C++ for flam3 renderer

## Key Aerial Files to Study

- `AerialUpdater/` - Main companion app code
- `manifest.json` - Version/hash manifest format
- `AerialMusicHelper/` - Background helper pattern

## Global Hotkey Research (January 2026)

### Package Options

| Package | Maintainer | API | macOS 15+ Fullscreen |
|---------|------------|-----|----------------------|
| [HotKey](https://github.com/soffes/HotKey) | @soffes | Carbon API | **Broken** |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | @sindresorhus | Carbon + workarounds | Better support |
| [SwiftKeys](https://github.com/jordanbaird/SwiftKeys) | @jordanbaird | Modern API | Unknown |

### Critical Finding

**Carbon-based global hotkeys don't work reliably in fullscreen on macOS 15+** (Sequoia). The fix is to use `CGEvent.tapCreate` API instead of Carbon, which requires Input Monitoring permission.

### Recommendation

1. **Primary**: Use `sindresorhus/KeyboardShortcuts` (2.0.1+) - more actively maintained
2. **Fallback**: If fullscreen issues persist, implement CGEvent-based hotkeys manually
3. **Permission**: Request Input Monitoring permission in System Preferences

### Code Example (KeyboardShortcuts)

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let voteUp = Self("voteUp", default: .init(.upArrow, modifiers: .command))
    static let voteDown = Self("voteDown", default: .init(.downArrow, modifiers: .command))
}

// In AppDelegate
KeyboardShortcuts.onKeyUp(for: .voteUp) {
    VoteManager.shared.voteUp()
}
```

## Other Companion App Examples

### Similar Architectures

1. **Aerial Companion** - Primary reference, same sandbox workaround pattern
2. **Menu bar utilities** - Pattern for background apps with status item
3. **LaunchAtLogin** - `sindresorhus/LaunchAtLogin` for startup management

### macOS Tahoe (26) Notes

Screen Saver preferences are now a modal dialog inside Wallpaper preferences, not a standalone pane. The command `open x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension` no longer works.
