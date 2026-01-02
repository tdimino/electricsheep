# Phase 2: Companion App Development

## Objective

Create ElectricSheepCompanion.app - a standalone macOS menu bar application that handles all network operations outside the screensaver sandbox, enabling sheep downloading, voting, and cache management on macOS Catalina+.

## Architecture Overview

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

## Technical Decisions

### Bridging Strategy
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Threading | C++ owns threads, Swift receives callbacks | Preserves C++ event loop, uses `withCheckedContinuation` for Swift async |
| Bridge API | ObjC++ class wrapper | Proven pattern, isolates C++ memory from ARC, safer for MVP |
| XML Parsing | Keep tinyXml in C++ | Reuse existing parser, return Swift structs via bridge |
| Singletons | ObjC++ wrapper with dispatch_once | Meyers pattern in C++, Swift sees clean singleton API |

### Concurrency (Catalina 10.15 Compatible)
- **No async/await** (requires macOS 12.0+)
- Use **GCD + closures** for all async operations
- C++ callbacks wrapped as Swift completion handlers
- Main thread for UI, background queues for network/disk

### SSL Handling
- **Keep SSL verification disabled** for sheepserver.net (self-signed cert)
- Match existing behavior to avoid breaking changes
- Note: May need adjustment for App Store submission

### IPC Between Components
- **CFNotificationCenter distributed notifications**
- Companion → Screensaver: Cache updates, new sheep available
- Screensaver → Companion: Playback tracking (for LRU), vote requests

## Core Services

| Service | Responsibility | Priority |
|---------|---------------|----------|
| `SheepDownloader` | Fetch sheep list, download videos | MVP |
| `CacheManager` | Manage cache directory, LRU eviction | MVP |
| `VoteProcessor` | Receive votes from screensaver, POST to server | MVP |
| `NotificationBridge` | Handle distributed notifications | MVP |
| `GlobalHotkeyManager` | Register Cmd+Up/Down for voting | MVP |
| `CredentialManager` | Keychain with iCloud sync | v0.2 |
| `AutoUpdater` | Sparkle framework integration | v0.2 |
| `AnalyticsService` | Anonymous usage stats | v0.2 |

## MVP Scope

**Included in v1.0:**
- Sheep downloading and caching
- Screensaver display of cached sheep
- Voting via global hotkeys
- Menu bar presence with sheep count
- Basic preferences window
- Screensaver installation from companion

**Deferred to v1.x:**
- Gold account support (higher resolution)
- Distributed rendering
- Auto-update via Sparkle
- Analytics

## Tasks

### 2.1 Project Setup

- [ ] Create Xcode project for macOS app
  - Bundle ID: `org.electricsheep.companion`
  - Deployment target: macOS 10.15 (Catalina)
  - Language: Swift 5.x
- [ ] Configure Info.plist
  - `LSUIElement = YES` (menu bar only, no dock icon)
  - `LSBackgroundOnly = NO`
- [ ] Set up code signing for development
- [ ] Create monochrome 'ES' menu bar icon (SF Symbol template style)
- [ ] Add Sparkle.framework (for future updates)

### 2.2 ObjC++ Bridge Layer

**Files to create:**
```
ESCompanionBridge/
├── ESCompanionBridge.h      # ObjC header (imported by Swift)
├── ESCompanionBridge.mm     # ObjC++ implementation
├── ESNetworkBridge.h/.mm    # Networking wrapper
├── ESParserBridge.h/.mm     # XML parsing wrapper
└── ESTypes.h                # Shared types (NSString, NSDictionary)
```

**Key bridge methods:**
```objc
@interface ESNetworkBridge : NSObject
+ (instancetype)shared;
- (void)fetchSheepListWithCompletion:(void(^)(NSArray<ESSheepInfo*>*, NSError*))completion;
- (void)downloadSheep:(ESSheepInfo*)sheep
           toPath:(NSString*)path
         progress:(void(^)(float))progress
       completion:(void(^)(BOOL, NSError*))completion;
- (void)submitVote:(NSInteger)vote
        forSheepID:(NSString*)sheepID
        completion:(void(^)(BOOL))completion;
@end
```

- [ ] Create ESCompanionBridge.h with ObjC types
- [ ] Implement ESNetworkBridge wrapping Networking.cpp
- [ ] Implement ESParserBridge wrapping tinyXml sheep list parsing
- [ ] Initialize C++ globals on first bridge access
- [ ] Add callback mechanism for progress reporting
- [ ] Test bridge in isolation before UI integration

### 2.3 Cache Manager

**Location:** `~/Library/Application Support/ElectricSheep/`

```
ElectricSheep/
├── sheep/
│   ├── free/           # Free sheep (gen 0-9999)
│   └── gold/           # Gold sheep (gen 10000+)
├── downloads/          # In-progress (.tmp files)
├── metadata/           # Sheep metadata JSON files
├── lists/              # Cached server XML
├── playback.json       # LRU tracking (sheep ID → last played timestamp)
├── config.json         # User preferences
├── offline_votes.json  # Queued offline votes
└── screensaver.saver   # Installed screensaver bundle
```

**Cache eviction:** LRU by playback time
- Track last-played timestamp per sheep
- Screensaver reports playback via distributed notification
- Companion updates playback.json
- When cache exceeds limit, delete least-recently-played

**Disk space handling:** Pause downloads when <1GB free

- [ ] Create directory structure on first launch
- [ ] Implement sheep file management (add, remove, list)
- [ ] Implement LRU tracking with playback.json
- [ ] Implement size-based eviction (configurable limit)
- [ ] Add disk space monitoring (pause at <1GB)
- [ ] Implement file validation (size check against server-reported size)

### 2.4 Sheep Downloader

**Flow:**
1. Fetch redirect URL from community.sheepserver.net
2. Fetch sheep list from v3d0.sheepserver.net (gzip XML)
3. Compare with local cache, queue missing sheep
4. Download from archive.org with progress tracking
5. Validate size, move to cache, notify screensaver

**Error handling:** Silent retry with exponential backoff (600s → 86400s)

- [ ] Implement redirect URL fetching
- [ ] Implement sheep list fetching and parsing (via bridge)
- [ ] Implement download queue with GCD
- [ ] Add progress reporting to menu bar
- [ ] Implement retry logic with exponential backoff
- [ ] Add distributed notification on new sheep available
- [ ] Auto-start downloads on app launch

### 2.5 Menu Bar UI

**Icon:** Monochrome 'ES' letters, changes color for status
- Normal: System template color
- Downloading: Blue accent
- Error: Red (silent, clears on success)

**Badge:** Sheep count (e.g., "247")

**Menu items:**
```
┌────────────────────────────┐
│ ● 247 sheep                │
│ ↓ Downloading 3 of 5...    │
├────────────────────────────┤
│ Pause Syncing              │
│ Preferences...             │
├────────────────────────────┤
│ About Electric Sheep       │
│ Quit                       │
└────────────────────────────┘
```

- [ ] Create NSStatusItem with 'ES' icon
- [ ] Implement badge for sheep count
- [ ] Build dropdown menu with SwiftUI
- [ ] Add download progress display
- [ ] Implement pause/resume syncing toggle
- [ ] Add About window

### 2.6 Preferences Window

**Settings (all in companion, none in screensaver):**
- Cache size limit (slider, default 2GB)
- Launch at login toggle
- Download on metered network (checkbox)
- Server selection (free/Gold - Gold deferred to v0.2)
- Reset cache button

- [ ] Create SwiftUI preferences window
- [ ] Implement cache size slider with live space display
- [ ] Add Launch at Login using SMAppService (10.13+) or ServiceManagement
- [ ] Store preferences in config.json
- [ ] Add "Reset Cache" with confirmation

### 2.7 Voting System

**Input:** Global hotkeys registered by companion
- Cmd+Up Arrow: Vote up
- Cmd+Down Arrow: Vote down

**Flow:**
1. User presses global hotkey
2. Companion sends distributed notification to screensaver: "which sheep is playing?"
3. Screensaver responds with current sheep ID
4. Companion POSTs vote to server immediately
5. On success, companion notifies screensaver to show feedback

**Feedback:** Subtle overlay (up/down arrow) appears briefly on screensaver

- [ ] Register global hotkeys using HotKey Swift package (github.com/soffes/HotKey)
- [ ] Implement screensaver query protocol via distributed notifications
- [ ] Implement vote submission via bridge
- [ ] Implement vote feedback notification to screensaver
- [ ] Handle case when screensaver is not running

### 2.8 Screensaver Installation

**Companion installs screensaver automatically:**
1. Bundle screensaver in companion app's Resources
2. On first launch, copy to ~/Library/Screen Savers/
3. On update, replace screensaver bundle
4. Handle permissions (may need user interaction for first install)

- [ ] Bundle screensaver in companion app
- [ ] Implement installation/update logic
- [ ] Add "Reinstall Screensaver" option in preferences
- [ ] Handle code signing for both components

### 2.9 Distributed Notifications

**Payload mechanism:** Notification name suffix (e.g., `org.electricsheep.SheepPlaying.248=12345=0=240`)

**Companion → Screensaver (5 notifications):**
| Notification | Payload | Purpose |
|--------------|---------|---------|
| `ESPong` | none | Response to ping |
| `ESCompanionLaunched` | capabilities (suffix) | Broadcast on startup with `voting=1,rendering=0,gold=0` |
| `ESCacheUpdated` | none | Reload cache |
| `ESVoteFeedback` | direction (`.up`/`.down` suffix) | Show vote overlay |
| `ESQueryCurrent` | none | Request current sheep |

**Screensaver → Companion (4 notifications):**
| Notification | Payload | Purpose |
|--------------|---------|---------|
| `ESPing` | none | Check if companion running |
| `ESSheepPlaying` | sheep ID (suffix) | Report current sheep |
| `ESPlaybackStarted` | sheep ID (suffix) | Update LRU timestamp |
| `ESCorruptedFile` | sheep ID (suffix) | Request re-download (high priority) |

See `plans/phase-4-ipc-communication.md` for full protocol details.

- [ ] Define ESNotificationNames.h with 9 notification constants
- [ ] Implement NotificationBridge class with prefix matching
- [ ] Broadcast ESCompanionLaunched with capabilities on app startup
- [ ] Respond to ESPing with ESPong
- [ ] Handle ESCorruptedFile with priority re-download
- [ ] Implement vote queue (FIFO, silent failure on network error)

### 2.10 Testing Strategy

**Mock server:** URLProtocol-based mocking
- Inject mock URLSessionConfiguration in tests
- Canned responses for sheep list, downloads, votes
- Error injection for retry logic testing

**Test coverage:**
- [ ] Unit tests for cache manager
- [ ] Unit tests for sheep parser
- [ ] Integration tests for download flow (mocked network)
- [ ] UI tests for preferences window
- [ ] Test on macOS 10.15, 11, 12, 13, 14

## Deliverables

- [ ] Functional companion app that downloads sheep
- [ ] ObjC++ bridge exposing C++ networking to Swift
- [ ] Shared cache accessible by screensaver
- [ ] Menu bar presence with status and sheep count
- [ ] Preferences window with cache management
- [ ] Global hotkey voting system
- [ ] Distributed notification protocol for screensaver IPC
- [ ] URLProtocol-based test suite

## Success Criteria

- [ ] App downloads sheep on first launch without user action
- [ ] Cache populates correctly at ~/Library/Application Support/ElectricSheep/
- [ ] App survives sleep/wake cycles without stalling
- [ ] Memory usage < 100MB idle
- [ ] Global hotkeys work when screensaver is fullscreen
- [ ] Votes are submitted successfully to server
- [ ] App runs on macOS 10.15 through 14.x

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| C++ bridge complexity | Start bridge early, test in isolation |
| Global hotkeys in fullscreen | Test on multiple macOS versions early |
| Screensaver sandbox limits | Research actual capabilities before Phase 3 |
| Sparkle notarization | Defer auto-update to v0.2, manual update for MVP |
| SSL rejection by Apple | HTTP fallback ready, document for App Store review |

## Dependencies

- Phase 1 completed (server validation done)
- Apple Developer account for signing
- Xcode 15+ (for Swift 5.9 features if needed later)
- Test Mac running Catalina for compatibility verification

## Timeline

**Target: Production-ready in 3+ months**

Suggested milestones:
1. Week 1-2: Project setup, bridge layer skeleton
2. Week 3-4: Bridge implementation, basic downloads working
3. Week 5-6: Menu bar UI, cache management
4. Week 7-8: Voting system, distributed notifications
5. Week 9-10: Preferences, screensaver installation
6. Week 11-12: Testing, polish, edge cases
7. Week 13+: Beta testing, bug fixes, documentation
