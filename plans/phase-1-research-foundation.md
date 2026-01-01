# Phase 1: Research & Foundation

## Objective

Build a comprehensive understanding of the Electric Sheep codebase and the Aerial Companion app architecture before writing any new code.

## Tasks

### 1.1 Analyze Electric Sheep Codebase

**Focus Areas:**

| Directory | Purpose | Priority |
|-----------|---------|----------|
| `client_generic/ContentDownloader/` | Network sheep fetching | High |
| `client_generic/ContentDecoder/` | Video decoding (ffmpeg) | Medium |
| `client_generic/DisplayOutput/` | Rendering pipeline | Medium |
| `client_generic/Networking/` | Server communication | High |
| `client_generic/MacBuild/` | macOS-specific code | High |

**Key Files to Study:**

- `ContentDownloader/SheepDownloader.cpp` - Download logic
- `ContentDownloader/Shepherd.cpp` - Queue coordination
- `Networking/Networking.cpp` - HTTP client wrapper
- `MacBuild/ESScreensaverView.m` - Screensaver entry point
- `MacBuild/ESConfiguration.m` - Settings/preferences

**Deliverables:**
- [x] Document reusable components (`agent_docs/code-bridge.md`)
- [x] Identify code that must be rewritten in Swift (`plans/decision-reuse-vs-rewrite.md`)
- [x] Map data flow for sheep downloading (`agent_docs/networking-protocol.md`)
- [x] Understand genome XML format (`agent_docs/file-formats.md`)

### 1.2 Study Aerial Companion Architecture

**Repository:** `github.com/AerialScreensaver/AerialCompanion`

**Key Patterns to Learn:**

1. **Manifest-based version checking**
   - How `manifest.json` stores version and SHA256
   - Version inference from download URLs

2. **Secure download with verification**
   - SHA256 hash validation
   - Code signing verification before install

3. **Background/foreground mode switching**
   - Menu bar presence toggle
   - Launch agent integration

4. **Homebrew integration**
   - Cask formula structure
   - Auto-update via Homebrew

**Deliverables:**
- [x] Document Aerial's architecture decisions (`agent_docs/companion-app-research.md`)
- [x] Identify patterns to adopt (manifest-based updates, menu bar, LaunchAtLogin)
- [x] Note differences (Electric Sheep has server rendering, voting)

### 1.3 Server Protocol Research

**Servers:**
| Server | IP | Purpose |
|--------|---|---------|
| `*.sheepserver.net` | 173.255.253.19 | All operations |
| `*.us.archive.org` | 207.241.*.* | Free sheep CDN |
| `d100rc88eim93q.cloudfront.net` | 54.192.55.139 | Gold sheep CDN |

**Protocol Details:**
- HTTP/HTTPS on ports 80/443
- XML-based genome format
- MPEG2 video downloads
- Vote submission API

**Deliverables:**
- [x] Document all API endpoints (`docs/server-api-reference.md`)
- [x] Capture sample requests/responses (validated live - see `agent_docs/networking-protocol.md`)
- [x] Identify authentication mechanism for Gold Sheep (MD5 hash, CloudFront CDN)

## Success Criteria

- [x] Complete architecture diagram of existing Electric Sheep client (`docs/existing-codebase-map.md`)
- [x] Decision document: what to reuse vs. rewrite (`plans/decision-reuse-vs-rewrite.md`)
- [x] API documentation for Electric Sheep servers (`docs/server-api-reference.md`)
- [x] Aerial Companion patterns documented (`agent_docs/companion-app-research.md`)

## Status: COMPLETE (January 2026)

All Phase 1 deliverables completed. Server connectivity verified. Ready for Phase 2.

## Dependencies

- Access to Electric Sheep source code (GPL2)
- Network access to test server communication
- Aerial Companion source for reference

## Estimated Effort

Research-only phase. No code changes.
