# Electric Sheep

Distributed computing screensaver that evolves abstract fractal flame animations via genetic algorithms. Created by Scott Draves in 1999. Currently broken on macOS Catalina+ due to screensaver sandboxing.

## Rules

- Do not commit unless explicitly requested

## Goal

Create a **Companion App architecture** to restore full functionality on modern macOS.

## Documentation

**For Claude Code (agent_docs/):**
- `agent_docs/macos-architecture.md` - How the macOS screensaver works
- `agent_docs/networking-protocol.md` - Server communication & download flow
- `agent_docs/rendering-pipeline.md` - FFmpeg decode to OpenGL display
- `agent_docs/companion-app-research.md` - Aerial Companion patterns
- `agent_docs/code-bridge.md` - Objective-C ↔ C++ bridge layer
- `agent_docs/file-formats.md` - Cache structure, genome XML, video formats

**For developers (docs/):**
- `docs/macos-screensaver-sandbox.md` - The Catalina problem explained
- `docs/companion-app-design.md` - Architecture for our solution
- `docs/existing-codebase-map.md` - Directory and file purposes
- `docs/server-api-reference.md` - Electric Sheep server endpoints
- `docs/build-instructions.md` - How to build the project

**Project planning:**
- `MANIFESTO.md` - Full project vision and technical plan
- `ROADMAP.md` - Milestones and progress tracking
- `plans/` - Detailed implementation phases

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

## Available Tools

This directory is indexed with **OSGrep** for semantic code search:
```bash
osgrep "how does sheep downloading work"  # Query the codebase
osgrep symbols Sheep                       # Find symbol definitions
osgrep trace SheepDownloader               # Trace call graphs
```

Additional research tools available:
- **Firecrawl** - Web scraping and URL content extraction
- **Exa Search** - Neural web search with category filtering
- **Ghidra** - Binary analysis if needed for reverse engineering

## License

GPL2 - see `client_generic/COPYING`
