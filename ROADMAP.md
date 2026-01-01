# Roadmap

## Current Status: Phase 0 - Planning Complete

The documentation structure is in place. Ready to begin implementation.

---

## Milestones

### v0.1.0 - MVP (Minimum Viable Patch)

**Goal:** Basic functionality restored on macOS Catalina+

- [ ] **Companion App Skeleton**
  - Menu bar presence
  - Basic UI structure
  - Cache directory setup

- [ ] **Sheep Downloading**
  - Connect to Electric Sheep servers
  - Download and cache sheep videos
  - Progress tracking

- [ ] **Simplified Screensaver**
  - Read from companion app cache
  - AVPlayer-based video playback
  - Active flag signaling

**Target:** TBD

---

### v0.2.0 - Core Features

**Goal:** Feature parity with pre-Catalina experience

- [ ] **Voting Functionality**
  - Vote on sheep via companion app
  - Queue votes when offline
  - Vote confirmation

- [ ] **Gold Sheep Authentication**
  - Account login
  - Keychain credential storage
  - Premium content access

- [ ] **Auto-Updates**
  - Version checking
  - Secure download and verification
  - Both app and screensaver updates

**Target:** TBD

---

### v1.0.0 - Full Parity

**Goal:** Complete Electric Sheep experience on modern macOS

- [ ] **Distributed Rendering**
  - Receive render jobs
  - Execute flam3 renderer
  - Upload completed frames

- [ ] **Apple Silicon Optimization**
  - Universal Binary
  - Native ARM64 performance
  - GPU acceleration exploration

- [ ] **Homebrew Formula**
  - Cask for easy installation
  - Auto-update integration

- [ ] **Documentation**
  - Complete user guide
  - Developer documentation
  - API reference

**Target:** TBD

---

## Future Enhancements (Post v1.0)

- [ ] 4K/8K resolution support
- [ ] Local sheep generation (no server dependency)
- [ ] tvOS Apple TV app
- [ ] Infinidream integration
- [ ] XPC-based IPC (replace file signaling)

---

## How to Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to help with any milestone.

## Progress Tracking

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 0: Planning | Complete | 100% |
| Phase 1: Research | Not Started | 0% |
| Phase 2: Companion App | Not Started | 0% |
| Phase 3: Screensaver | Not Started | 0% |
| Phase 4: IPC | Not Started | 0% |
| Phase 5: Server | Not Started | 0% |
