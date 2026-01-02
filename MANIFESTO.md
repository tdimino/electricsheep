# fix: Electric Sheep macOS Catalina+ Compatibility Patch

## Overview

Electric Sheep, the legendary distributed computing screensaver created by Scott Draves in 1999, stopped working properly on macOS Catalina (10.15) and later due to Apple's introduction of screensaver sandboxing. This plan proposes creating a companion app architecture (similar to Aerial's proven solution) to restore full Electric Sheep functionality on modern macOS.

## Problem Statement

### The Root Cause

Apple introduced a **security sandbox for third-party screensavers** in macOS Catalina (10.15), released October 2019. All third-party screensavers now run inside `legacyScreenSaver.appex`, a sandboxed container that restricts:

| Restriction | Impact on Electric Sheep |
|------------|--------------------------|
| Network Access | Cannot download new sheep from servers |
| Filesystem Access | Cannot write sheep cache outside sandbox container |
| Keyboard Input | Cannot process voting (up/down arrows) |
| Process Spawning | Cannot run renderer with elevated permissions |
| Auto-Updates | Cannot update the screensaver bundle |

### Current State (from Electric Sheep FAQ)

> "Apple introduced a sandbox for screensavers in Catalina (10.15), and this broke downloading, voting, and the other interactive keyboard commands. It works when run as a regular application, and the screensaver can display content downloaded by the application, but the screensaver by itself is prevented from downloading new designs."

### What Still Works
- Displaying previously cached/downloaded sheep animations
- Running Electric Sheep as a regular application (not as screensaver)
- Manual sheep downloads when app is running

### What's Broken
- Downloading new sheep while screensaver is active
- User voting on sheep (keyboard interaction)
- Uploading rendered frames (distributed computing)
- Auto-update functionality
- Interactive keyboard commands

## Proposed Solution

Create an **Electric Sheep Companion App** following the proven architecture used by the Aerial Screensaver project, which successfully solved this same problem.

### Architecture Overview

```
+----------------------------------+
|     Electric Sheep Companion     |
|          (macOS App)             |
|----------------------------------|
| - Runs outside sandbox           |
| - Full network access            |
| - Full filesystem access         |
| - Handles all downloads          |
| - Processes user votes           |
| - Manages sheep cache            |
| - Renders frames (distributed)   |
| - Auto-updates both components   |
+----------------------------------+
         |
         | Shared Data Directory
         | ~/Library/Application Support/ElectricSheep/
         |
         v
+----------------------------------+
|    Electric Sheep Screensaver    |
|         (.saver bundle)          |
|----------------------------------|
| - Runs in sandbox                |
| - Read-only access to cache      |
| - Displays cached sheep          |
| - Minimal resource usage         |
+----------------------------------+
```

### Key Components

#### 1. Electric Sheep Companion App (`ElectricSheepCompanion.app`)

A standalone macOS application that:

- **Runs as a menu bar app** (optional background mode)
- **Downloads sheep** from Electric Sheep servers
- **Manages the sheep cache** in a shared location
- **Handles user authentication** (Gold Sheep login)
- **Processes keyboard votes** when active
- **Renders frames** for distributed computing contribution
- **Auto-updates** both itself and the screensaver bundle
- **Provides settings UI** for all Electric Sheep preferences

#### 2. Modified Screensaver Bundle (`ElectricSheep.saver`)

A simplified screensaver that:

- **Reads pre-downloaded sheep** from the shared cache
- **Displays animations** without network access
- **Reports playback** via distributed notifications (for LRU tracking)
- **Shows vote feedback** overlay when companion sends notification
- **Minimal footprint** - just video playback

#### 3. Shared Data Layer

- **Cache Directory**: `~/Library/Application Support/ElectricSheep/`
  - `sheep/free/` - Free sheep videos (gen 0-9999)
  - `sheep/gold/` - Gold sheep videos (gen 10000+)
  - `downloads/` - In-progress downloads (.tmp files)
  - `metadata/` - Sheep metadata JSON files
  - `playback.json` - LRU tracking (sheep ID → last played timestamp)
  - `config.json` - User preferences
  - `offline_votes.json` - Queued offline votes
- **Communication**: Distributed notifications (CFNotificationCenter)
  - Real-time, no polling required
  - Works across sandbox boundaries
  - No race conditions

## Technical Approach

### Phase 1: Research & Foundation

**Analyze Existing Codebase:**
- Review Electric Sheep source at `github.com/scottdraves/electricsheep`
- Focus on `client_generic/` directory structure:
  - `ContentDownloader/` - Network sheep fetching
  - `ContentDecoder/` - Video decoding (ffmpeg-based)
  - `DisplayOutput/` - Rendering pipeline
  - `Networking/` - Server communication
  - `MacBuild/` - macOS-specific code
- Identify components that can be reused vs. need rewriting

**Study Aerial's Companion Architecture:**
- Review `AerialScreensaver/AerialCompanion` implementation
- Key patterns:
  - Manifest-based version checking
  - Secure download with SHA256 verification
  - Code signing verification before install
  - Background/foreground mode switching
  - Homebrew integration option

### Phase 2: Companion App Development

**Create Swift + ObjC++ Menu Bar App:**

The companion app uses an ObjC++ bridge layer to reuse battle-tested C++ networking code while providing a modern Swift UI.

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
```

**Technical Decisions:**

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Concurrency | GCD + Closures | macOS 10.15 Catalina compatible (no async/await) |
| Threading | C++ owns threads | Swift receives callbacks via completion handlers |
| Bridge API | ObjC++ wrapper | Isolates C++ memory from ARC, proven pattern |
| XML Parsing | Keep tinyXml in C++ | Reuse existing parser, return Swift structs |

**Core Services:**

| Service | Responsibility |
|---------|---------------|
| `SheepDownloader` | Fetch sheep from `*.sheepserver.net` via C++ bridge |
| `CacheManager` | Manage `~/Library/Application Support/ElectricSheep/` |
| `VoteProcessor` | Handle voting via global hotkeys + immediate server POST |
| `NotificationBridge` | CFNotificationCenter for screensaver IPC |
| `GlobalHotkeyManager` | Register Cmd+Up/Down for voting |
| `AutoUpdater` | Sparkle framework for updates (v1.1+) |

### Phase 3: Screensaver Simplification

**Key Decision: Keep C++ OpenGL**

After research, we're keeping the existing C++ OpenGL rendering rather than migrating to AVPlayer. This preserves Electric Sheep's signature **dual-blend crossfade** effect where two sheep videos are alpha-blended simultaneously during transitions.

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Renderer | Keep C++ OpenGL | Preserves dual-blend crossfade |
| C++ Scope | Strip to display-only | Remove network/voting code |
| Vote Overlay | Reuse OpenGL HUD | Existing Hud.h system |
| Companion Detection | Ping/pong (2s timeout) | ESPing → wait → ESPong |
| Multi-Monitor | Same content synced | Shared static variables |
| Preview Mode | Animated logo only | No video decode |
| Empty Cache | Static message + logo | "Downloading sheep..." |

**Modified Architecture:**

```
ElectricSheep.saver (Simplified)
├── ESScreensaverView.m (simplified)
├── ESCacheReader (new - reads sheep/)
├── ESNotificationHandler (new - IPC)
│
├── C++ Core (Stripped Down):
│   ├── FrameDisplay.h (preserved - dual-blend)
│   ├── CrossFade.h (preserved - transitions)
│   ├── RendererGL.cpp (preserved - OpenGL)
│   ├── ContentDecoder.cpp (preserved - FFmpeg)
│   └── Hud.h (preserved - vote overlay)
│
└── REMOVED:
    ├── ContentDownloader/
    ├── Networking/
    └── SheepUploader.cpp
```

See `plans/phase-3-screensaver-simplification.md` for full details.

### Phase 4: Inter-Process Communication

**Method: Distributed Notifications (CFNotificationCenter)**

Distributed notifications are the best balance of simplicity and real-time capability for screensaver ↔ companion communication.

| Criteria | Distributed Notifications | File-Based | XPC Service |
|----------|--------------------------|------------|-------------|
| Complexity | Low | Low | High |
| Real-time | Yes | No (polling) | Yes |
| Sandbox compatible | Yes | Yes | Complex |
| Race conditions | None | Possible | None |

**Notification Protocol (9 notifications):**

Payloads encoded as notification name suffix (e.g., `org.electricsheep.SheepPlaying.248=12345=0=240`)

| Notification | Direction | Purpose |
|--------------|-----------|---------|
| `ESPing` | Saver → Companion | Check if companion running |
| `ESPong` | Companion → Saver | Companion is alive |
| `ESCompanionLaunched` | Companion → Saver | Broadcast on startup (capabilities: `voting=1,rendering=0,gold=0`) |
| `ESCacheUpdated` | Companion → Saver | Reload cache |
| `ESVoteFeedback` | Companion → Saver | Show vote overlay (`.up`/`.down` suffix) |
| `ESQueryCurrent` | Companion → Saver | Request current sheep |
| `ESSheepPlaying` | Saver → Companion | Report current sheep (ID in suffix) |
| `ESPlaybackStarted` | Saver → Companion | Update LRU timestamp (ID in suffix) |
| `ESCorruptedFile` | Saver → Companion | Request re-download (ID in suffix, high priority) |

**Voting Flow:**
1. User presses Cmd+Up (global hotkey)
2. Companion sends `ESQueryCurrent` notification
3. Screensaver responds with `ESSheepPlaying` (sheep ID)
4. Companion POSTs vote to server immediately
5. Companion sends `ESVoteFeedback` notification
6. Screensaver shows subtle overlay (↑ or ↓)

### Phase 5: Server Communication

**Maintain Compatibility with Electric Sheep Servers:**

| Server | IP | Purpose |
|--------|---|---------|
| `*.sheepserver.net` | 173.255.253.19 | All operations |
| `*.us.archive.org` | 207.241.*.* | Free sheep CDN |
| `d100rc88eim93q.cloudfront.net` | 54.192.55.139 | Gold sheep CDN |

**Protocol Implementation:**
- HTTP/HTTPS on ports 80/443
- XML-based genome format
- MPEG2 video downloads
- Vote submission API

## Acceptance Criteria

### Functional Requirements

- [ ] Companion app downloads sheep while running in background
- [ ] Screensaver displays cached sheep without network access
- [ ] User can vote on sheep (keyboard input when companion app focused)
- [ ] Gold Sheep authentication works
- [ ] Distributed rendering contributes frames to server
- [ ] Auto-update functionality for both components
- [ ] Clean uninstall process

### Non-Functional Requirements

- [ ] Works on macOS 10.15 Catalina through macOS 14 Sonoma
- [ ] Native Apple Silicon support (Universal Binary)
- [ ] Signed and notarized for Gatekeeper approval
- [ ] Memory usage under 200MB for screensaver
- [ ] CPU usage minimal when displaying (not rendering)
- [ ] Battery-aware (reduces activity on battery power)

### Quality Gates

- [ ] Code signed with valid Developer ID
- [ ] Notarized by Apple
- [ ] Tested on Intel and Apple Silicon Macs
- [ ] Homebrew cask formula created
- [ ] Documentation updated

## Alternative Approaches Considered

### 1. XPC Service Inside Screensaver Bundle
**Rejected**: XPC services in legacy screensaver bundles are not picked up by launchd. The sandbox inheritance means any spawned process is equally restricted.

### 2. Launch Agent for Background Work
**Possible Alternative**: Could use a Launch Agent (`~/Library/LaunchAgents/`) instead of a companion app. Less discoverable for users but fully automated.

### 3. Wait for Apple to Fix
**Rejected**: It's been 5+ years since Catalina. Apple shows no intention of relaxing screensaver sandbox restrictions.

### 4. Port to Screen Saver AppExtension
**Future Consideration**: Apple's new AppExtension format for screensavers is undocumented and unavailable to third parties. If Apple opens this up, it would be the cleanest solution.

## Dependencies & Prerequisites

### External Dependencies
- Electric Sheep server infrastructure (maintained by Scott Draves)
- Apple Developer account for code signing ($99/year)
- Access to Electric Sheep source code (GPL2 licensed)

### Technical Dependencies
- Xcode 14+ for development
- Swift 5.7+ / Objective-C interop
- FFmpeg libraries for video decoding (already in Electric Sheep)
- libcurl for network operations (already in Electric Sheep)

### Community Dependencies
- Approval/collaboration from Scott Draves (project creator)
- Testing from Electric Sheep community

## Risk Analysis & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Server API changes | High | Low | Document current API, monitor for changes |
| Apple further restricts screensavers | Medium | Medium | Companion app remains functional regardless |
| Electric Sheep servers go offline | High | Low | Offline mode with cached sheep |
| Code signing costs | Low | Certain | Required $99/year investment |
| Performance issues on older Macs | Medium | Medium | Test on various hardware, add quality settings |

## Resource Requirements

### Development
- macOS development expertise (Swift, Objective-C)
- Familiarity with screensaver architecture
- Understanding of Electric Sheep protocol

### Infrastructure
- Apple Developer account
- Test machines (Intel + Apple Silicon)
- Access to Electric Sheep servers for testing

## Future Considerations

### Potential Enhancements
1. **Native Apple Silicon rendering** - Optimize fractal flame renderer for M1/M2 GPU
2. **4K/8K support** - Higher resolution sheep for Retina displays
3. **Local rendering mode** - Generate sheep locally without server dependency
4. **Infinidream integration** - Scott Draves' new project at `infinidream.ai`
5. **tvOS port** - Apple TV screensaver version

### Long-term Sustainability
- Consider creating an open-source fork maintained by community
- Establish communication with Scott Draves for official endorsement
- Create documentation for others to contribute

## References & Research

### Internal References
- Electric Sheep source: `github.com/scottdraves/electricsheep`
- `client_generic/MacBuild/` - macOS build configuration
- `client_generic/ContentDownloader/` - Download implementation
- `client_generic/Networking/` - Server communication

### External References
- Aerial Companion: `github.com/AerialScreensaver/AerialCompanion`
- Electric Sheep FAQ: `electricsheep.org/faq/#osx`
- Apple ScreenSaver Framework: `developer.apple.com/documentation/screensaver`
- XPC Services: `developer.apple.com/documentation/xpc`
- macOS Sandboxing: `developer.apple.com/documentation/security/app_sandbox`

### Related Work
- Aerial Screensaver solved same problem: `github.com/JohnCoates/Aerial`
- Homebrew deprecated Electric Sheep cask: `formulae.brew.sh/cask/electric-sheep`
- Scott Draves' new project: `infinidream.ai`

---

## Implementation Priority

1. **v1.0.0 - MVP (Minimum Viable Product)**
   - Companion app that downloads sheep in background
   - Modified screensaver that reads from shared cache
   - Voting via global hotkeys (Cmd+Up/Down)
   - Subtle vote feedback overlay on screensaver
   - Menu bar presence with sheep count
   - Basic preferences window (cache size, launch at login)
   - Companion installs screensaver automatically
   - Distributed notifications IPC

2. **v1.1.0 - Enhanced Features**
   - Gold Sheep authentication (1280x720 content)
   - Keychain + iCloud sync for credentials
   - Auto-update via Sparkle framework
   - Anonymous usage analytics (opt-in)

3. **v2.0.0 - Full Parity**
   - Distributed rendering contribution
   - Universal Binary (Intel + Apple Silicon optimized)
   - Homebrew cask formula
   - Advanced settings

---

*This plan follows the proven architecture pattern established by the Aerial Screensaver project, which has successfully operated under macOS Catalina+ sandbox restrictions since 2020.*
