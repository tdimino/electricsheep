# Phase 3: Screensaver Simplification

## Objective

Modify the existing Electric Sheep screensaver to operate in read-only mode, displaying sheep from the companion app's cache without any network access. Preserve the signature dual-blend crossfade effect.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Renderer | Keep C++ OpenGL | Preserves dual-blend crossfade (two sheep visible during transitions) |
| C++ Scope | Strip to display-only | Extract only FrameDisplay + Renderer code, remove network/voting |
| Vote Overlay | Reuse OpenGL HUD | Existing Hud.h system, no z-order issues with fullscreen OpenGL |
| Empty Cache | Static message + icon | Display "Downloading sheep..." with logo, simple and informative |
| Companion Detection | Notification ping/pong | Send ESPing, wait 2s for ESPong response |
| Playlist Selection | Random + LRU weighted | Random shuffle, prioritize least-recently-played, extensible for ratings |
| Multi-Monitor | Same content synced | All screens show identical sheep, unified experience |
| Preview Mode | Animated logo only | Light on resources, no video decode |
| Error Handling | Skip + notify companion | Skip corrupted files, notify companion to re-download |
| Config Sheet | Companion only | No screensaver settings, just "Open Companion" button |
| No Companion | Play cached + warning | Play available cache, show subtle warning message |

## Current Architecture

**Key files:**
- `client_generic/MacBuild/ESScreensaverView.m` (405 lines) - Main screensaver view
- `client_generic/MacBuild/ESScreensaver.cpp` (309 lines) - C++ bridge
- `client_generic/DisplayOutput/OpenGL/ESOpenGLView.m` (48 lines) - OpenGL context holder
- `client_generic/Client/FrameDisplay.h` (377 lines) - Frame rendering with crossfade
- `client_generic/Client/CrossFade.h` (99 lines) - Transition effects
- `client_generic/Client/Hud.h` (77 lines) - HUD overlay system

**Current dependencies:**
- Player.cpp (700+ lines) - Full playback coordinator
- ContentDecoder.cpp (850+ lines) - FFmpeg video decoding
- ContentDownloader/ - Network code (TO BE REMOVED)
- Networking/ - libcurl wrapper (TO BE REMOVED)

## Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ElectricSheep.saver                         │
│                    (Simplified, Read-Only)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │ ESScreensaver│  │ Cache Reader    │  │ Notification       │  │
│  │ View.m      │  │ (replaces       │  │ Handler            │  │
│  │ (simplified)│  │ downloader)     │  │ (new)              │  │
│  └──────┬──────┘  └────────┬────────┘  └──────────┬──────────┘  │
│         │                  │                      │              │
│  ┌──────┴──────────────────┴──────────────────────┴────────────┐ │
│  │           C++ Core (Stripped Down)                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │ │
│  │  │ FrameDisplay │  │ CrossFade    │  │  Hud (vote       │   │ │
│  │  │ (preserved)  │  │ (preserved)  │  │  overlay)        │   │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │ │
│  │  ┌──────────────┐  ┌──────────────┐                         │ │
│  │  │ RendererGL   │  │ ContentDecode│  REMOVED:               │ │
│  │  │ (preserved)  │  │ (preserved)  │  - Networking           │ │
│  │  └──────────────┘  └──────────────┘  - ContentDownloader    │ │
│  │                                       - SheepUploader       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    CFNotificationCenter
                    (Distributed Notifications)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ElectricSheepCompanion.app                   │
│                  (Downloads, Voting, Settings)                  │
└─────────────────────────────────────────────────────────────────┘
```

## Tasks

### 3.1 Strip C++ to Display-Only

Extract minimal code for video playback and rendering:

**Keep:**
- `FrameDisplay.h/.cpp` - Frame rendering with crossfade
- `CrossFade.h` - Transition effects
- `RendererGL.cpp` - OpenGL rendering
- `ContentDecoder.cpp` - FFmpeg video decode
- `Hud.h/.cpp` - Overlay system (for vote feedback)
- `TextureFlat*.cpp` - Texture management

**Remove:**
- `ContentDownloader/` - All download code
- `Networking/` - libcurl wrapper
- `SheepUploader.cpp` - Upload code
- `Shepherd.cpp` - Download coordination
- Sparkle framework integration
- Voting keyboard handlers

- [ ] Create ESScreensaverCore/ directory with extracted code
- [ ] Remove network dependencies from build
- [ ] Remove Sparkle framework
- [ ] Remove keyboard voting handlers from ESScreensaverView.m
- [ ] Update Xcode project to exclude removed files

### 3.2 Implement Cache Reader

Replace download logic with cache reading:

```objc
@interface ESCacheReader : NSObject
@property (readonly) NSString *cachePath;  // ~/Library/Application Support/ElectricSheep/sheep/
@property (readonly) NSArray<NSURL *> *availableSheep;

- (instancetype)initWithCachePath:(NSString *)path;
- (NSURL *)nextSheepURL;  // Random + LRU weighted selection
- (void)markPlayed:(NSURL *)sheepURL;  // Update LRU tracking
- (BOOL)validateSheep:(NSURL *)sheepURL;  // Check file integrity
@end
```

**Cache directory structure:**
```
~/Library/Application Support/ElectricSheep/
├── sheep/
│   ├── free/           # Free sheep (gen 0-9999)
│   │   ├── 248=12345=0=240.avi
│   │   └── 248=67890=0=180.avi
│   └── gold/           # Gold sheep (gen 10000+)
├── metadata/           # Sheep metadata JSON
├── playback.json       # LRU tracking
└── config.json         # Shared settings
```

- [ ] Create ESCacheReader class
- [ ] Implement directory scanning for .avi files
- [ ] Implement random + LRU weighted selection algorithm
- [ ] Read playback.json for LRU data
- [ ] Implement file validation (size check)
- [ ] Handle missing/empty cache gracefully

### 3.3 Implement Distributed Notification Handler

Handle IPC with companion app:

```objc
@interface ESNotificationHandler : NSObject
- (void)startListening;
- (void)stopListening;

// Outgoing notifications
- (void)postSheepPlaying:(NSString *)sheepID;
- (void)postPlaybackStarted:(NSString *)sheepID;
- (void)postPing;  // For companion detection
- (void)postCorruptedFile:(NSString *)sheepID;

// Incoming notification handlers
- (void)handleCacheUpdated;      // Reload cache
- (void)handleVoteFeedback:(NSInteger)direction;  // Show overlay
- (void)handleQueryCurrent;      // Respond with current sheep ID
- (void)handlePong;              // Companion is running
@end
```

**Notification Protocol (9 notifications):**

Payloads use notification name suffix (e.g., `org.electricsheep.SheepPlaying.248=12345=0=240`)

| Notification | Direction | Payload | Purpose |
|--------------|-----------|---------|---------|
| `ESPing` | Saver → Companion | none | Check if companion running |
| `ESPong` | Companion → Saver | none | Companion is alive |
| `ESCompanionLaunched` | Companion → Saver | capabilities (suffix) | Companion started, clear warning |
| `ESCacheUpdated` | Companion → Saver | none | Reload sheep list |
| `ESVoteFeedback` | Companion → Saver | direction (`.up`/`.down` suffix) | Show vote overlay |
| `ESQueryCurrent` | Companion → Saver | none | Request current sheep |
| `ESSheepPlaying` | Saver → Companion | sheep ID (suffix) | Report current sheep |
| `ESPlaybackStarted` | Saver → Companion | sheep ID (suffix) | Update LRU |
| `ESCorruptedFile` | Saver → Companion | sheep ID (suffix) | Request re-download |

**Capabilities flags (ESCompanionLaunched):** `voting=1,rendering=0,gold=0`

- [ ] Create ESNotificationHandler class
- [ ] Implement CFNotificationCenter observers
- [ ] Implement notification posting methods
- [ ] Implement ping/pong for companion detection
- [ ] Handle ESVoteFeedback to trigger HUD overlay
- [ ] Post ESPlaybackStarted on each sheep start

### 3.4 Implement Vote Feedback Overlay

Create vote arrow overlay using existing HUD system:

```cpp
// ESVoteOverlay.h (new CHudEntry subclass)
class CVoteOverlay : public CHudEntry
{
    DisplayOutput::spCTextureFlat m_spArrowTexture;
    bool m_bUpVote;  // true = up arrow, false = down arrow

public:
    CVoteOverlay(uint32 width, uint32 height);
    void ShowVote(bool upVote);  // Trigger display
    virtual bool Render(const fp8 _time, DisplayOutput::spCRenderer _spRenderer);
};
```

**Behavior:**
- Arrow appears in corner when vote received
- Fade in over 0.3s
- Hold for 1.5s
- Fade out over 0.5s
- Up arrow = green, Down arrow = red

- [ ] Create CVoteOverlay class extending CHudEntry
- [ ] Load arrow textures (up/down arrows bundled in Resources)
- [ ] Implement fade in/hold/fade out animation
- [ ] Register with CHudManager
- [ ] Trigger from ESNotificationHandler

### 3.5 Implement Graceful Degradation

**Empty cache behavior:**
- Display Electric Sheep logo (bundled in Resources)
- Show "Downloading sheep..." text
- Check periodically for new files (every 30s)
- Post ESPing to companion on each check

```objc
- (void)showEmptyCacheMessage {
    // Render logo and message using existing HUD system
    // or simple Core Graphics drawing
}
```

**Companion not running:**
- Send ESPing on startup
- Wait 2 seconds for ESPong
- If no response, set `companionRunning = NO`
- Show subtle "Companion app not running" message (corner text)
- Continue playing cached sheep normally

- [ ] Create empty cache message view
- [ ] Bundle Electric Sheep logo in Resources
- [ ] Implement companion detection ping/pong
- [ ] Create subtle warning overlay for missing companion
- [ ] Implement periodic cache refresh when empty

### 3.6 Preview Mode

System Preferences preview window handling:

```objc
- (void)startAnimation {
    if (m_isPreview) {
        [self startPreviewAnimation];  // Animated logo only
        return;
    }
    [self startFullAnimation];  // Normal sheep playback
}

- (void)startPreviewAnimation {
    // Load animated logo
    // Simple rotation/pulse animation
    // No video decode
}
```

- [ ] Detect preview mode via frame size check (< 400x300)
- [ ] Create simple animated logo for preview
- [ ] Skip video decode entirely in preview
- [ ] Keep preview lightweight (< 50MB memory)

### 3.7 Multi-Monitor Support

Sync playback across all screens:

```objc
// Use shared state for multi-screen sync
static NSString *s_currentSheepID;
static NSTimeInterval s_playbackPosition;

- (void)syncWithOtherScreens {
    // Read shared state
    // Seek to same position
}
```

**Approach:**
- First screen to start becomes "leader"
- Leader posts current sheep ID and position
- Other screens read and sync
- Use shared static variables (all screensaver instances share process)

- [ ] Implement leader election (first view becomes leader)
- [ ] Share playback state via static variables
- [ ] Sync new screens to current position
- [ ] Handle screen add/remove gracefully

### 3.8 Configuration Sheet

Minimal config sheet - just opens companion:

```objc
- (NSWindow *)configureSheet {
    // Create simple window with:
    // - "Electric Sheep" title
    // - "Settings are managed by the companion app" text
    // - "Open Companion App" button
    // - "Get Companion App" link (if not installed)
}
```

- [ ] Create minimal config window NIB
- [ ] Add "Open Companion App" button
- [ ] Detect if companion is installed
- [ ] Show download link if not installed
- [ ] Remove ESConfiguration.m (was settings UI)

## Code Changes Summary

| File | Action |
|------|--------|
| `ESScreensaverView.m` | Simplify - remove network, voting, Sparkle |
| `ESScreensaverView.h` | Simplify interface |
| `ESOpenGLView.*` | Keep as-is (just OpenGL context) |
| `ESConfiguration.*` | Replace with minimal "Open Companion" sheet |
| `ESScreensaver.cpp` | Simplify - remove network functions |
| `ContentDownloader/*` | Remove entirely |
| `Networking/*` | Remove entirely |
| `FrameDisplay.h` | Keep - core rendering |
| `CrossFade.h` | Keep - transition effects |
| `Hud.h/.cpp` | Keep - add vote overlay |

**New files:**
- `ESCacheReader.h/.m` - Cache directory reading
- `ESNotificationHandler.h/.m` - Distributed notifications
- `ESVoteOverlay.h/.cpp` - Vote feedback HUD entry
- `ESPreviewView.h/.m` - Animated logo for preview

## Deliverables

- [ ] Simplified screensaver bundle (< 5MB without FFmpeg)
- [ ] OpenGL video playback from cache with dual-blend crossfades
- [ ] Distributed notification IPC
- [ ] Vote feedback overlay via HUD system
- [ ] Preview mode with animated logo
- [ ] Multi-monitor sync
- [ ] Minimal config sheet with "Open Companion" button
- [ ] Graceful handling of empty cache and missing companion

## Success Criteria

- [ ] Screensaver runs without network errors
- [ ] Displays sheep from companion app cache
- [ ] Dual-blend crossfade transitions preserved
- [ ] Vote overlay appears when companion sends notification
- [ ] Memory usage < 200MB
- [ ] CPU usage minimal (video decode only)
- [ ] Works on Intel and Apple Silicon
- [ ] Preview shows animated logo
- [ ] Multi-monitor shows synced content

## Dependencies

- Phase 2 companion app with populated cache
- Test machine with macOS Catalina+
- Electric Sheep logo assets for empty cache / preview

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| C++ stripping breaks build | Incremental removal with build after each change |
| OpenGL deprecated on macOS | Still works, future migration to Metal possible |
| Notification timing issues | 2s timeout for ping/pong, async handling |
| Multi-monitor sync drift | Periodic re-sync every 60s |
| FFmpeg bundle size | Ship minimal FFmpeg libs, just decode codecs |
