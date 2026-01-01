# The macOS Screensaver Sandbox Problem

## Background

Electric Sheep was created by Scott Draves in 1999 as a distributed computing screensaver that evolves abstract fractal flame animations through genetic algorithms. For over two decades, it worked seamlessly on macOS.

## What Changed in Catalina

In **macOS 10.15 Catalina (2019)**, Apple introduced significant security restrictions for third-party screensavers:

- Screensavers now run inside `legacyScreenSaver.appex`, a sandboxed app extension
- This sandbox blocks:
  - **Network access** - Cannot download sheep from servers
  - **Filesystem writes** - Cannot update cache directory
  - **Keyboard input** - May block voting functionality
  - **Background processes** - Cannot spawn download/render threads

## Impact on Electric Sheep

| Feature | Before Catalina | After Catalina |
|---------|-----------------|----------------|
| Sheep downloading | Works | Blocked |
| Voting | Works | Blocked |
| Distributed rendering | Works | Blocked |
| Auto-updates (Sparkle) | Works | Partially broken |
| Cache management | Works | Read-only |

## Current Workaround

Electric Sheep can still run as a **standalone application** (not as a screensaver):

1. Download from [electricsheep.org](https://electricsheep.org)
2. Run `Electric Sheep.app` directly from Applications
3. Leave running in background to download sheep
4. Videos play in app window, not as screensaver

**Limitation:** Not a true screensaver experience. Doesn't activate when idle.

## Failed Attempts

### Sparkle Auto-Update
- Sparkle framework could check for updates
- But caused `ScreenSaverEngine` to lose keyboard/mouse focus
- Users couldn't exit screensaver without force-quit
- Removed in version 2.0.0 (Aerial project)

### XPC from Screensaver
- Attempted to create XPC connection to helper
- Sandbox prevents outbound XPC connections
- Cannot communicate with outside processes

### Entitlements
- App Sandbox entitlements don't apply to screensavers
- Apple's legacy screensaver sandbox is hardcoded
- No official way to request network access

## The Solution: Companion App Architecture

The only proven solution is to split into two components:

```
┌─────────────────────────────────┐
│    Companion App (Menu Bar)     │
│  - Full network access          │
│  - Can write to filesystem      │
│  - Handles downloads/voting     │
│  - Runs outside sandbox         │
└─────────────────────────────────┘
              │
              │ Shared Cache Directory
              ▼
┌─────────────────────────────────┐
│    Screensaver (.saver)         │
│  - Read-only cache access       │
│  - Display only                 │
│  - No network operations        │
│  - Runs inside sandbox          │
└─────────────────────────────────┘
```

## Reference Implementation

The **Aerial Screensaver** successfully implemented this pattern:

- [AerialCompanion](https://github.com/AerialScreensaver/AerialCompanion) - Menu bar app
- [Aerial](https://github.com/JohnCoates/Aerial) - Screensaver (20K+ stars)

Key learnings from Aerial:
1. Companion handles all network operations
2. Screensaver reads from shared cache
3. File-based IPC for coordination
4. Manifest-based update system

## Next Steps

See [companion-app-design.md](companion-app-design.md) for our implementation plan.
