# Phase 2: Companion App Development

## Objective

Create the ElectricSheepCompanion.app - a standalone macOS menu bar application that handles all network operations outside the screensaver sandbox.

## Architecture

```swift
// ElectricSheepCompanion/AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var sheepDownloader: SheepDownloader!
    var frameRenderer: DistributedRenderer!
    var cacheManager: CacheManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupBackgroundServices()
        startSheepSync()
    }
}
```

## Core Services

| Service | Responsibility | Priority |
|---------|---------------|----------|
| `SheepDownloader` | Fetch sheep from `*.sheepserver.net` | MVP |
| `CacheManager` | Manage `~/Library/Application Support/ElectricSheep/` | MVP |
| `DistributedRenderer` | Render frames for server upload | v1.0 |
| `VoteProcessor` | Handle keyboard voting when enabled | v0.2 |
| `AutoUpdater` | Check and install updates for both components | v0.2 |
| `ServerCommunicator` | HTTP/HTTPS communication with servers | MVP |

## Tasks

### 2.1 Project Setup

- [ ] Create Xcode project for macOS app
- [ ] Configure code signing and notarization
- [ ] Set up menu bar status item
- [ ] Create app icon

### 2.2 Cache Manager

**Location:** `~/Library/Application Support/ElectricSheep/`

```
ElectricSheep/
├── sheep/           # Downloaded video files
├── genomes/         # Sheep genome data (XML)
├── config.json      # User preferences
├── manifest.json    # Version tracking
└── active.flag      # Screensaver status indicator
```

- [ ] Create cache directory structure
- [ ] Implement cache size management
- [ ] Add cache cleanup for old sheep

### 2.3 Sheep Downloader

**Reference:** `client_generic/ContentDownloader/SheepDownloader.cpp`

- [ ] Port download logic to Swift
- [ ] Implement queue management
- [ ] Add progress tracking
- [ ] Handle network errors gracefully

### 2.4 Server Communicator

**Reference:** `client_generic/Networking/Networking.cpp`

- [ ] Implement HTTP client using URLSession
- [ ] Parse XML genome responses
- [ ] Handle authentication for Gold Sheep
- [ ] Implement retry logic

### 2.5 Menu Bar UI

- [ ] Status icon (downloading, idle, error states)
- [ ] Dropdown menu with:
  - Current sheep count
  - Download progress
  - Preferences...
  - Check for Updates
  - Quit

### 2.6 Preferences Window

- [ ] Server selection (free vs. Gold)
- [ ] Cache size limit
- [ ] Download frequency
- [ ] Launch at login toggle
- [ ] Background/foreground mode

## Deliverables

- [ ] Functional companion app that downloads sheep
- [ ] Shared cache accessible by screensaver
- [ ] Menu bar presence with status
- [ ] Basic preferences UI

## Success Criteria

- [ ] App downloads sheep in background
- [ ] Cache populates correctly
- [ ] App survives sleep/wake cycles
- [ ] Memory usage < 100MB idle

## Dependencies

- Phase 1 research completed
- Apple Developer account for signing
- Test access to Electric Sheep servers
