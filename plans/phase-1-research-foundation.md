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
- [ ] Document reusable components
- [ ] Identify code that must be rewritten in Swift
- [ ] Map data flow for sheep downloading
- [ ] Understand genome XML format

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
- [ ] Document Aerial's architecture decisions
- [ ] Identify patterns to adopt
- [ ] Note differences (Electric Sheep has server rendering, voting)

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
- [ ] Document all API endpoints
- [ ] Capture sample requests/responses
- [ ] Identify authentication mechanism for Gold Sheep

## Success Criteria

- [ ] Complete architecture diagram of existing Electric Sheep client
- [ ] Decision document: what to reuse vs. rewrite
- [ ] API documentation for Electric Sheep servers
- [ ] Aerial Companion patterns documented

## Dependencies

- Access to Electric Sheep source code (GPL2)
- Network access to test server communication
- Aerial Companion source for reference

## Estimated Effort

Research-only phase. No code changes.
