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
├── mpeg/           # Downloaded sheep videos
├── xml/            # Server lists, genomes
├── jpeg/           # Rendered frames
├── active.flag     # IPC: screensaver running
├── current.json    # IPC: currently playing
└── vote.pending    # IPC: vote requests
```

### IPC Options

**Option A: File-Based (MVP)**
- Simple, no entitlements needed
- Polling required (not real-time)
- Easy to debug (check files)

**Option B: XPC Service (Future)**
- Real-time communication
- Complex setup
- May have sandbox issues

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
