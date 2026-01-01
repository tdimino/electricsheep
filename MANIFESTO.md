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
- **Signals the companion app** (via shared file/XPC) when active
- **Minimal footprint** - just video playback

#### 3. Shared Data Layer

- **Cache Directory**: `~/Library/Application Support/ElectricSheep/`
  - `sheep/` - Downloaded sheep video files
  - `genomes/` - Sheep genome data
  - `config.plist` - Shared configuration
  - `active.flag` - Screensaver active indicator
- **Communication**: File-based signaling or XPC service

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

**Create Swift/Objective-C Menu Bar App:**

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

**Core Services:**

| Service | Responsibility |
|---------|---------------|
| `SheepDownloader` | Fetch sheep from `*.sheepserver.net` |
| `CacheManager` | Manage `~/Library/Application Support/ElectricSheep/` |
| `DistributedRenderer` | Render frames for server upload |
| `VoteProcessor` | Handle keyboard voting when enabled |
| `AutoUpdater` | Check and install updates for both components |
| `ServerCommunicator` | HTTP/HTTPS communication with Electric Sheep servers |

### Phase 3: Screensaver Simplification

**Modify Screensaver to Read-Only Mode:**

```objective-c
// ElectricSheepSaver.m
@interface ElectricSheepView : ScreenSaverView
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSArray<NSURL *> *sheepQueue;
@end

@implementation ElectricSheepView

- (void)startAnimation {
    [super startAnimation];
    [self loadSheepFromCache];
    [self signalCompanionAppActive:YES];
    [self playNextSheep];
}

- (void)loadSheepFromCache {
    NSString *cachePath = [@"~/Library/Application Support/ElectricSheep/sheep"
                           stringByExpandingTildeInPath];
    // Read cached sheep files
}

@end
```

### Phase 4: Inter-Process Communication

**Option A: File-Based Signaling (Simpler)**
```
~/Library/Application Support/ElectricSheep/
├── active.flag          # Created when screensaver starts
├── vote.pending         # Contains vote data for companion to process
└── config.json          # Shared configuration
```

**Option B: XPC Service (More Robust)**
```swift
// XPC Service in Companion App
class SheepXPCService: NSObject, SheepXPCProtocol {
    func requestNextSheep(reply: @escaping (URL?) -> Void)
    func submitVote(sheepId: String, vote: Int)
    func reportPlaybackStatus(sheepId: String, position: Double)
}
```

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

1. **MVP (Minimum Viable Patch)**
   - Companion app that downloads sheep in background
   - Modified screensaver that reads from shared cache
   - Basic settings UI

2. **Phase 2**
   - Voting functionality
   - Gold Sheep authentication
   - Auto-update system

3. **Phase 3**
   - Distributed rendering contribution
   - Apple Silicon optimization
   - Advanced settings

---

*This plan follows the proven architecture pattern established by the Aerial Screensaver project, which has successfully operated under macOS Catalina+ sandbox restrictions since 2020.*
