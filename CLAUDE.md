# Electric Sheep

Distributed computing screensaver that evolves abstract fractal flame animations via genetic algorithms. Created by Scott Draves in 1999. Currently broken on macOS Catalina+ due to screensaver sandboxing.

## Goal

Create a **Companion App architecture** to restore full functionality on modern macOS (see `docs/electric-sheep-macos-patch.md`).

## Stack

- **Language**: C/C++ (87%), Objective-C (1.5%), Lua 5.1
- **Renderer**: flam3 fractal flame algorithm (`github.com/scottdraves/flam3`)
- **Video**: FFmpeg for MPEG2 decoding
- **Network**: libcurl for HTTP/HTTPS
- **XML**: tinyXml for genome parsing
- **Build**: Autotools (Linux), Xcode (macOS), MSVC (Windows)

## Structure

```
client_generic/
├── MacBuild/           # macOS Xcode project & screensaver code
│   ├── ESScreensaverView.m   # Main screensaver view (ScreenSaverView subclass)
│   ├── ESConfiguration.m     # Settings/preferences
│   └── ElectricSheep.xcodeproj
├── ContentDownloader/  # Sheep download & server sync
│   ├── SheepDownloader.cpp   # Downloads sheep from servers
│   ├── SheepUploader.cpp     # Uploads rendered frames
│   ├── Shepherd.cpp          # Coordinates download queue
│   └── Sheep.h               # Sheep data model
├── Networking/         # libcurl HTTP wrapper
├── ContentDecoder/     # FFmpeg video decoding
├── DisplayOutput/      # OpenGL rendering
├── Client/             # Main client logic
├── Common/             # Shared utilities
└── TupleStorage/       # Key-value storage
```

## Server Infrastructure

| Server | IP | Purpose |
|--------|---|---------|
| `*.sheepserver.net` | 173.255.253.19 | All operations |
| `*.us.archive.org` | 207.241.*.* | Free sheep CDN |
| `d100rc88eim93q.cloudfront.net` | 54.192.55.139 | Gold sheep CDN |

Communication: HTTP (80) / HTTPS (443). Genome format: XML.

## The macOS Problem

Apple sandboxed third-party screensavers in Catalina (10.15). When running as `.saver`:
- Network access blocked (no sheep downloads)
- Filesystem restricted (can't write cache)
- Keyboard input blocked (no voting)

**Current workaround**: Run as regular app, not screensaver.

## Companion App Solution

Split into two components:

1. **ElectricSheepCompanion.app** - Menu bar app outside sandbox
   - Downloads sheep, processes votes, renders frames
   - Writes to `~/Library/Application Support/ElectricSheep/`

2. **ElectricSheep.saver** - Simplified screensaver
   - Read-only access to shared cache
   - Display only, no network

See: Aerial Screensaver's proven implementation (`github.com/AerialScreensaver/AerialCompanion`)

## Build (macOS)

```bash
# Open Xcode project
open client_generic/MacBuild/ElectricSheep.xcodeproj

# Dependencies: FFmpeg, libcurl, boost (bundled in repo)
```

## Key Files for Companion App Work

- `MacBuild/ESScreensaverView.m` - Screensaver entry point (needs simplification)
- `ContentDownloader/SheepDownloader.cpp` - Download logic (move to companion)
- `ContentDownloader/Shepherd.cpp` - Queue coordination (move to companion)
- `Networking/Networking.cpp` - HTTP client (reuse in companion)

## Related Projects

- **flam3**: `github.com/scottdraves/flam3` - Fractal flame renderer
- **Aerial**: `github.com/JohnCoates/Aerial` - Reference companion app architecture
- **Infinidream**: `infinidream.ai` - Scott Draves' new project (1080p sheep)

## License

GPL2 - see `client_generic/COPYING`
