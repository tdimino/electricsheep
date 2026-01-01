# Phase 3: Screensaver Simplification

## Objective

Modify the existing Electric Sheep screensaver to operate in read-only mode, displaying sheep from the companion app's cache without any network access.

## Current Architecture

**File:** `client_generic/MacBuild/ESScreensaverView.m`

The existing screensaver:
- Downloads sheep directly (blocked by sandbox)
- Manages its own cache
- Handles voting via keyboard
- Uses OpenGL for rendering
- Includes Sparkle for updates (blocked by sandbox)

## Target Architecture

```objective-c
// ElectricSheepSaver.m (simplified)
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

## Tasks

### 3.1 Remove Network Dependencies

- [ ] Remove all download code from screensaver
- [ ] Remove Sparkle framework integration
- [ ] Remove upload/rendering code
- [ ] Remove voting keyboard handlers

### 3.2 Implement Cache Reader

- [ ] Read sheep list from companion app cache
- [ ] Handle missing cache gracefully (show message)
- [ ] Implement playlist shuffling
- [ ] Track playback position

### 3.3 Migrate to AVPlayer

**Current:** OpenGL-based custom renderer
**Target:** AVPlayer for video playback

- [ ] Replace ESOpenGLView with AVPlayerView
- [ ] Handle video transitions (crossfade)
- [ ] Support multiple display resolutions
- [ ] Implement aspect ratio handling

### 3.4 Companion App Signaling

**Option A: File-based (simpler)**
```
~/Library/Application Support/ElectricSheep/
├── active.flag          # Created when screensaver starts
└── current_sheep.txt    # Currently playing sheep ID
```

- [ ] Create active flag on startAnimation
- [ ] Delete active flag on stopAnimation
- [ ] Write current sheep ID for companion to read

### 3.5 Graceful Degradation

- [ ] Show friendly message if cache is empty
- [ ] Display "Install Companion App" instructions
- [ ] Handle corrupted video files

### 3.6 Preview Mode

- [ ] Ensure preview works in System Preferences
- [ ] Scale appropriately for preview window
- [ ] Show sample animation if no cache

## Code Changes

| File | Action |
|------|--------|
| `ESScreensaverView.m` | Major refactor - remove network, add cache reading |
| `ESScreensaverView.h` | Simplify interface |
| `ESOpenGLView.*` | Remove (replace with AVPlayerView) |
| `ESConfiguration.*` | Simplify - remove server settings |

## Deliverables

- [ ] Simplified screensaver bundle
- [ ] Video playback from cache
- [ ] Active flag signaling
- [ ] Preview mode support

## Success Criteria

- [ ] Screensaver runs without network errors
- [ ] Displays sheep from companion app cache
- [ ] Memory usage < 200MB
- [ ] CPU usage minimal (video decode only)
- [ ] Works on Intel and Apple Silicon

## Dependencies

- Phase 2 companion app with populated cache
- Test machine with macOS Catalina+
