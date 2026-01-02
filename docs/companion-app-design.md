# Companion App Design

## Overview

This document describes the architecture for `ElectricSheepCompanion.app`, a menu bar application that restores full Electric Sheep functionality on macOS Catalina (10.15) and later.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ElectricSheepCompanion.app                   │
│                         (Swift + ObjC++)                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Menu Bar   │  │ Preferences │  │   Download Manager      │  │
│  │  (SwiftUI)  │  │  (SwiftUI)  │  │   (GCD + Closures)      │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
│         │                │                     │                │
│  ┌──────┴────────────────┴─────────────────────┴──────────────┐ │
│  │                   ESCompanionBridge.mm                      │ │
│  │              (Objective-C++ Wrapper Layer)                  │ │
│  └──────────────────────────┬──────────────────────────────────┘ │
│                             │                                    │
│  ┌──────────────────────────┴──────────────────────────────────┐ │
│  │              C++ Core (Reused from client_generic)          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │ │
│  │  │ Networking   │  │ SheepParser  │  │  TinyXML         │   │ │
│  │  │ (libcurl)    │  │              │  │                  │   │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    CFNotificationCenter
                    (Distributed Notifications)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ElectricSheep.saver                         │
│                    (Display + Vote Input)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Companion App
| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI Layer | SwiftUI | Modern, declarative, Catalina compatible |
| Concurrency | GCD + Closures | Catalina compatible (no async/await) |
| Networking | C++ libcurl via bridge | Reuse battle-tested code |
| XML Parsing | C++ tinyXml via bridge | Reuse existing parser |
| Credentials | Keychain + iCloud sync | Secure, syncs across Macs |
| Settings | UserDefaults + config.json | Shared with screensaver |
| Updates | Sparkle framework | Industry standard (v1.1+) |

### Bridge Layer
| Component | Technology | Rationale |
|-----------|------------|-----------|
| Wrapper | Objective-C++ (.mm) | Bridges Swift and C++ cleanly |
| Pattern | Singleton wrapper | C++ globals wrapped in dispatch_once |
| Threading | C++ owns threads | Swift receives callbacks |

### Screensaver
- Keep existing C++/Objective-C for video decoding
- Simplify to read-only cache access
- Remove all network code
- Add distributed notification handling

## App Presence

- **Menu bar only** (`LSUIElement = YES`)
- No dock icon, no Cmd+Tab
- 'ES' monochrome icon (SF Symbol template style)
- Badge showing sheep count

## Components

### 1. Menu Bar Controller

```swift
class MenuBarController: NSObject {
    var statusItem: NSStatusItem  // 'ES' icon + badge

    // Badge: sheep count (e.g., "247")
    // Icon colors: normal (template), downloading (blue), error (red)

    func buildMenu() -> NSMenu {
        // ● 247 sheep
        // ↓ Downloading 3 of 5...
        // ─────────────────────
        // Pause Syncing
        // Preferences...
        // ─────────────────────
        // About Electric Sheep
        // Quit
    }
}
```

### 2. Download Manager

```swift
class DownloadManager {
    // GCD-based, completion handler pattern (Catalina compatible)

    func fetchSheepList(completion: @escaping (Result<[Sheep], Error>) -> Void)
    func downloadSheep(_ sheep: Sheep,
                       progress: @escaping (Float) -> Void,
                       completion: @escaping (Result<URL, Error>) -> Void)
    func pruneCache()  // LRU by playback time
}
```

### 3. Cache Manager

**Location:** `~/Library/Application Support/ElectricSheep/`

```
ElectricSheep/
├── sheep/
│   ├── free/           # Free sheep (gen 0-9999)
│   └── gold/           # Gold sheep (gen 10000+)
├── downloads/          # In-progress (.tmp files)
├── metadata/           # Sheep metadata JSON
├── playback.json       # LRU tracking (sheep ID → last played)
├── config.json         # User preferences
├── offline_votes.json  # Queued offline votes
└── screensaver.saver   # Installed screensaver bundle
```

**Eviction:** LRU by playback time
- Screensaver reports playing sheep via distributed notification
- Companion updates playback.json
- Oldest-played sheep deleted first when cache full

**Disk space:** Pause downloads when <1GB free

### 4. Vote Manager

```swift
class VoteManager {
    // Global hotkeys registered via Carbon API or MASShortcut
    // Cmd+Up = vote up, Cmd+Down = vote down

    func registerHotkeys()
    func handleVote(direction: VoteDirection) {
        // 1. Query screensaver: "which sheep?"
        // 2. POST vote to server immediately
        // 3. Notify screensaver to show feedback
    }
}
```

### 5. Notification Bridge

```swift
class NotificationBridge {
    // CFNotificationCenter distributed notifications

    // Outgoing (Companion → Screensaver):
    // - ESPong: response to ping (companion is alive)
    // - ESCacheUpdated: new sheep available
    // - ESVoteFeedback: show overlay (direction: up/down)
    // - ESQueryCurrent: request current sheep ID

    // Incoming (Screensaver → Companion):
    // - ESPing: screensaver checking if companion running (respond with ESPong)
    // - ESSheepPlaying: currently displaying (sheep ID)
    // - ESPlaybackStarted: update LRU timestamp
    // - ESCorruptedFile: mark file for re-download

    func handlePing() {
        // Respond immediately with ESPong
        post(ESPongNotification)
    }

    func handleCorruptedFile(sheepID: String) {
        // Mark for re-download
        DownloadManager.shared.markForRedownload(sheepID)
    }
}
```

## IPC Protocol

### Distributed Notifications (CFNotificationCenter)

**Payload mechanism:** Notification name suffix (e.g., `org.electricsheep.SheepPlaying.248=12345=0=240`)

| Notification | Direction | Payload | Purpose |
|--------------|-----------|---------|---------|
| `ESPing` | Saver → Companion | none | Check if companion running |
| `ESPong` | Companion → Saver | none | Companion is alive |
| `ESCompanionLaunched` | Companion → Saver | capabilities (suffix) | Companion started, clear warning |
| `ESCacheUpdated` | Companion → Saver | none | Reload cache |
| `ESVoteFeedback` | Companion → Saver | direction (`.up`/`.down` suffix) | Show vote overlay |
| `ESQueryCurrent` | Companion → Saver | none | Request current sheep |
| `ESSheepPlaying` | Saver → Companion | sheep ID (suffix) | Report current sheep |
| `ESPlaybackStarted` | Saver → Companion | sheep ID (suffix) | Update LRU timestamp |
| `ESCorruptedFile` | Saver → Companion | sheep ID (suffix) | Request re-download (high priority) |

**Capabilities flags (ESCompanionLaunched):** `voting=1,rendering=0,gold=0`

### Why Distributed Notifications?
- Native macOS API (CFNotificationCenter)
- Works across sandbox boundaries
- Low overhead, no file I/O
- Simpler than XPC for this use case

### Companion Detection Protocol

On screensaver startup:
1. Screensaver posts `ESPing`
2. Waits 2 seconds for `ESPong` response
3. If no response: `companionRunning = NO`, show subtle warning
4. If response: `companionRunning = YES`, normal operation
5. Play cached sheep regardless of companion status

**Passive detection:** If companion launches after screensaver, it broadcasts `ESCompanionLaunched`. Screensaver listens for this and clears warning, parsing capabilities to know what features are available.

## User Settings

All settings in companion app (none in screensaver preferences).

| Setting | Default | Description |
|---------|---------|-------------|
| Cache Size | 2 GB | Maximum cache size |
| Launch at Login | false | Start companion on boot |
| Download on Metered | true | Download on cellular/metered |

## Voting Workflow

1. User presses Cmd+Up or Cmd+Down (global hotkey)
2. Companion receives hotkey event
3. Companion sends `ESQueryCurrent` notification
4. Screensaver responds with `ESSheepPlaying` (sheep ID)
5. Companion POSTs vote to server immediately
6. On success, companion sends `ESVoteFeedback` notification
7. Screensaver shows subtle overlay (up/down arrow)

## Screensaver Installation

Companion installs screensaver automatically:
1. Screensaver bundled in companion's Resources
2. On first launch, copy to `~/Library/Screen Savers/`
3. On companion update, replace screensaver bundle
4. "Reinstall Screensaver" option in preferences

## Error Handling

- **Network errors:** Silent retry with exponential backoff (600s → 86400s)
- **Server unreachable:** Continue with cached sheep, no notification
- **Disk full:** Pause downloads at <1GB, resume when space available
- **Screensaver not running:** Vote hotkeys do nothing (no error)
- **Corrupted files:** Screensaver skips and posts `ESCorruptedFile`, companion re-downloads
- **Companion not running:** Screensaver shows subtle warning, continues with cached sheep

## Build Requirements

- Xcode 14+
- macOS 10.15+ SDK
- Deployment target: macOS 10.15 (Catalina)
- Swift 5.x
- Apple Developer account for signing

## Testing Strategy

- **Network mocking:** URLProtocol-based injection
- **Unit tests:** Cache manager, sheep parser, LRU logic
- **Integration tests:** Download flow with mocked responses
- **Manual testing:** macOS 10.15, 11, 12, 13, 14

## OpenGL Status (January 2026)

### Current State

OpenGL is **deprecated but functional** on macOS:

| Aspect | Status |
|--------|--------|
| API Version | OpenGL 4.1 (legacy implementation) |
| Deprecated Since | macOS 10.14 Mojave (2018) |
| Still Working | Yes, as of macOS 15 Sequoia |
| Removal Timeline | No announced date |

### Our Decision

**Keep OpenGL** for the screensaver renderer. Rationale:

1. **Dual-blend crossfade** requires custom shader - not trivial to replace
2. **Battle-tested code** in `DisplayOutput/OpenGL/RendererGL.cpp`
3. **No removal timeline** - Apple hasn't announced when OpenGL will stop working
4. **Metal migration** would be significant effort with no immediate benefit

### Risk Mitigation

1. **Monitor Apple announcements** for deprecation warnings
2. **Metal port** could be future v2.0 work if needed
3. **MoltenVK** as intermediate option (Vulkan → Metal translation)

### Compiler Warnings

Suppress OpenGL deprecation warnings in build settings:

```bash
# In Xcode Build Settings
OTHER_CFLAGS = -Wno-deprecated-declarations
```

Or per-file:
```c
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include <OpenGL/gl.h>
#pragma clang diagnostic pop
```
