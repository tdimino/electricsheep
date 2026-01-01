# Companion App Design

## Overview

This document describes the architecture for `ElectricSheepCompanion.app`, a menu bar application that restores full Electric Sheep functionality on macOS Catalina and later.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                ElectricSheepCompanion.app                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Menu Bar UI │  │  Downloader │  │  Vote Manager       │  │
│  │  - Status   │  │  - Fetch    │  │  - Queue votes      │  │
│  │  - Progress │  │  - Cache    │  │  - Submit on        │  │
│  │  - Settings │  │  - Verify   │  │    reconnect        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                           │                                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Shared Cache                         ││
│  │  ~/Library/Application Support/ElectricSheep/           ││
│  │  ├── mpeg/  (videos)                                    ││
│  │  ├── xml/   (lists, genomes)                            ││
│  │  └── ipc/   (communication files)                       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              │ File-based IPC
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  ElectricSheep.saver                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Video       │  │  Cache      │  │  IPC Watcher        │  │
│  │ Player      │  │  Reader     │  │  - Watch for        │  │
│  │ (AVPlayer)  │  │  (read-only)│  │    vote requests    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Companion App (Swift)
- **SwiftUI** - Modern declarative UI
- **Combine** - Reactive data flow
- **URLSession** - Native networking (replaces libcurl)
- **FileManager** - Cache management
- **Keychain** - Secure credential storage
- **UserDefaults** - Settings persistence

### Screensaver (Objective-C/C++)
- Keep existing C++ backend for video decoding
- Simplify to read-only cache access
- Remove network code

## Components

### 1. Menu Bar Controller

```swift
class MenuBarController: NSObject {
    var statusItem: NSStatusItem
    var downloadManager: DownloadManager
    var voteManager: VoteManager

    // Menu items
    func buildMenu() -> NSMenu {
        // - Download Status (X sheep cached)
        // - Progress indicator
        // - Separator
        // - Preferences...
        // - Check for Updates
        // - Separator
        // - Quit
    }
}
```

### 2. Download Manager

```swift
class DownloadManager: ObservableObject {
    @Published var cachedCount: Int
    @Published var downloadProgress: Double
    @Published var isDownloading: Bool

    func fetchSheepList() async throws -> [Sheep]
    func downloadSheep(_ sheep: Sheep) async throws
    func pruneCache(maxSize: Int64)
}
```

### 3. Vote Manager

```swift
class VoteManager {
    var pendingVotes: [Vote] = []

    func vote(_ sheepId: String, direction: VoteDirection)
    func submitPendingVotes() async
    func watchForVoteRequests()  // File watcher
}
```

### 4. Authentication

```swift
class AuthManager {
    func login(username: String, password: String) async throws -> UserRole
    func storeCredentials() throws  // Keychain
    func loadCredentials() throws -> Credentials?
}
```

## IPC Protocol

### Files in `~/Library/Application Support/ElectricSheep/ipc/`

| File | Writer | Reader | Purpose |
|------|--------|--------|---------|
| `active.flag` | Screensaver | Companion | Screensaver is running |
| `current.json` | Screensaver | Companion | Currently playing sheep |
| `vote.request` | Screensaver | Companion | Vote request |
| `companion.status` | Companion | Screensaver | Companion status |

### active.flag
```json
{
  "pid": 12345,
  "started": "2024-01-15T10:30:00Z",
  "display": "Main Display"
}
```

### current.json
```json
{
  "id": "sheep_12345",
  "file": "00042=01234=01230=01235.avi",
  "generation": 42,
  "position": 45.2,
  "duration": 90.0
}
```

### vote.request
```json
{
  "sheep_id": "sheep_12345",
  "vote": 1,
  "timestamp": "2024-01-15T10:31:00Z"
}
```

## User Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Cache Size | 2000 MB | Maximum cache per generation type |
| Auto-download | true | Download sheep automatically |
| Launch at Login | false | Start companion on boot |
| Show Menu Bar | true | Display status icon |
| Check Updates | weekly | Update check frequency |

## Voting Workflow

Since screensaver may not receive keyboard input:

1. User configures global hotkey in companion preferences
2. Companion listens for hotkey via accessibility API
3. Companion reads `current.json` to get playing sheep
4. Companion submits vote to server
5. Companion shows notification of vote success

## Build Phases

### Phase 1: MVP
- [x] Menu bar skeleton
- [ ] Download manager (fetch list, download sheep)
- [ ] Basic settings UI
- [ ] Cache reader for screensaver

### Phase 2: Full Features
- [ ] Voting system
- [ ] Gold authentication
- [ ] Keychain integration
- [ ] Auto-update via Sparkle

### Phase 3: Advanced
- [ ] Distributed rendering
- [ ] XPC service (replace file IPC)
- [ ] Apple Silicon optimization
