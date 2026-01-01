# Decision: Reuse vs Rewrite

## Summary

**Recommendation: Hybrid approach** - Reuse networking/download logic via C++ bridging, rewrite UI and coordination in Swift.

## Component Analysis

### Networking Layer (`Networking.cpp` - 13K lines)
**Decision: REUSE via bridging**

Reasons to reuse:
- libcurl wrapper is battle-tested
- Handles gzip decompression, chunked transfer, SSL
- Retry logic with exponential backoff already implemented
- Server protocol is stable and undocumented edge cases handled

Bridging approach:
- Create Objective-C++ wrapper exposing key methods
- Swift calls wrapper for list fetch, downloads
- Keep curl session management in C++

### Content Downloader (`SheepDownloader.cpp`, `Shepherd.cpp` - 2K lines)
**Decision: REUSE core logic, REWRITE orchestration**

Reuse:
- Sheep parsing and validation
- Download queue logic
- Cache management

Rewrite:
- Thread coordination (use GCD instead of boost::thread)
- Progress reporting (use Combine/async-await)
- Coordinator pattern for menu bar integration

### Content Decoder (`ContentDecoder.cpp` - 850 lines)
**Decision: REUSE via bridging**

FFmpeg decode pipeline is complex and working:
- Handles H.264 in AVI container
- Frame extraction and timing
- Memory management for decoded frames

Companion app may not need decoding (screensaver handles display).

### Display Output (`RendererGL.cpp` - 650 lines)
**Decision: SCREENSAVER ONLY**

Companion app doesn't render - just downloads and manages cache.
Screensaver uses existing OpenGL code unchanged.

### UI / Menu Bar
**Decision: REWRITE in Swift**

New components needed:
- SwiftUI menu bar interface
- Download progress display
- Settings window (moved from screensaver)
- LaunchAtLogin integration
- Notification handling

## Bridging Strategy

```
ElectricSheepCompanion.app (Swift)
    │
    ├── Swift UI layer (menus, settings)
    │
    ├── Swift service layer (coordination)
    │
    └── ObjC++ Bridge (ESCompanionBridge.mm)
            │
            ├── CSheepDownloader wrapper
            ├── CShepherd wrapper
            └── CNetworking wrapper
```

## Estimated Effort

| Component | Approach | Effort |
|-----------|----------|--------|
| Menu bar UI | New Swift | Medium |
| Settings migration | New Swift | Medium |
| ObjC++ bridge layer | New | Medium |
| Download orchestration | Partial rewrite | Low |
| FFmpeg decoding | Reuse | None |
| Networking | Reuse | None |

## Risk Assessment

**Lower risk with reuse:**
- Server protocol edge cases already handled
- Memory management in C++ is stable
- No regression in download reliability

**Higher risk with rewrite:**
- Server protocol has undocumented behaviors
- Authentication flow has subtle requirements
- Retry logic timing is tuned

## Recommendation

1. **Phase 2A:** Create ObjC++ bridge for networking layer
2. **Phase 2B:** Build Swift menu bar app using bridge
3. **Phase 2C:** Migrate settings from screensaver to companion
4. **Phase 2D:** Simplify screensaver to display-only

This preserves the working networking code while modernizing the user-facing components.
