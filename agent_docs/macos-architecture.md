# macOS Screensaver Architecture

## Overview

Electric Sheep on macOS uses a hybrid Objective-C/C++ architecture where the screensaver UI is in Objective-C and the core logic (downloading, decoding, rendering) is in C++.

## Key Classes

### ESScreensaverView (Objective-C)
**File:** `client_generic/MacBuild/ESScreensaverView.m`

The main screensaver controller. Inherits from `ScreenSaverView` when `SCREEN_SAVER` is defined.

**Critical Methods:**
- `-initWithFrame:isPreview:` - Initialize screensaver, setup Sparkle updater
- `-startAnimation` - Create OpenGL view, call `ESScreensaver_Start()`, spawn animation thread
- `-stopAnimation` - Stop thread, call `ESScreensaver_Stop()` and `ESScreensaver_Deinit()`
- `-_animationThread` - Background loop calling `ESScreensaver_DoFrame()` per frame
- `-keyDown:` - Map key codes to internal events for voting

**Members:**
```objc
ESOpenGLView *glView;           // OpenGL rendering view
NSTimer *animationTimer;        // Frame update timer
NSLock *animationLock;          // Thread synchronization
BOOL m_isStopped;               // Animation state
BOOL m_isPreview;               // Preview vs full mode
ESConfiguration* m_config;      // Settings dialog
SUUpdater* m_updater;           // Sparkle auto-update
```

### ESConfiguration (Objective-C)
**File:** `client_generic/MacBuild/ESConfiguration.m`

Settings dialog with 47+ UI controls. Loads/saves via C++ bridge.

**Key Settings:**
- Display: FPS, display mode, multi-monitor handling
- Network: Proxy host/port, credentials
- Cache: Size limits, content folder path
- Account: Drupal login for Gold membership

### ESOpenGLView (Objective-C)
**File:** `client_generic/DisplayOutput/OpenGL/ESOpenGLView.m`

OpenGL context wrapper with pixel format configuration:
- Double-buffered, 32-bit RGBA, 16-bit depth
- Hardware accelerated, no recovery
- Integrated GPU hint for MacBook Pro

### CElectricSheep_Mac (C++)
**File:** `client_generic/Client/client_mac.h`

Mac-specific client implementation. Handles:
- App Support directory resolution
- System proxy detection via `SCDynamicStoreCopyProxies`
- AC power status via IOKit (`IOPSCopyPowerSourcesInfo`)
- Instance locking via file descriptor

## Threading Model

```
Main Thread (ESScreensaverView)
├─ -startAnimation
│  ├─ Creates ESOpenGLView
│  ├─ Calls ESScreensaver_Start() [C++]
│  └─ Spawns background thread
│
Background Thread
├─ -_animationThread
│  └─ Loop: ESScreensaver_DoFrame()
│     ├─ gClient.Update() [C++]
│     │  ├─ Download sheep
│     │  ├─ Decode video
│     │  └─ Render frame
│     └─ SwapBuffers
│
Main Thread
└─ -stopAnimation
   └─ ESScreensaver_Deinit()
```

## Build Targets

The Xcode project produces two targets:
1. **Application** (APPL) - Standalone app with MainMenu.nib
2. **Screensaver** (BNDL) - `.saver` bundle with ESScreensaverView as principal class

## Sandbox Restrictions (Catalina+)

When running as `.saver` in macOS 10.15+:
- Network access blocked via `legacyScreenSaver.appex`
- Filesystem writes restricted
- Keyboard input may be blocked for voting

**Workaround:** Run as standalone application, not screensaver.
