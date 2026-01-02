# Roadmap

## Current Status: Phase 1 Complete, Phase 2 Ready

Phase 1 research complete. Server connectivity verified. Ready for companion app development.

---

## Milestones

### v1.0.0 - MVP (Minimum Viable Product)

**Goal:** Full core functionality on macOS Catalina+ (10.15 - 14.x)

- [ ] **Companion App**
  - Menu bar presence with 'ES' icon + sheep count badge
  - ObjC++ bridge to reuse C++ networking code
  - Auto-start downloads on launch
  - Preferences window (cache size, launch at login)
  - Companion installs screensaver automatically

- [ ] **Sheep Downloading**
  - Connect to sheepserver.net and archive.org
  - Download and cache sheep videos (800x598)
  - LRU cache eviction by playback time
  - Silent retry with exponential backoff

- [ ] **Voting System**
  - Global hotkeys (Cmd+Up/Down) via companion
  - Immediate vote submission to server
  - Subtle overlay feedback in screensaver

- [ ] **Simplified Screensaver**
  - Read from shared cache
  - Display-only (no network access)
  - Report playback for LRU tracking
  - Show tasteful warning if companion not running

- [ ] **IPC**
  - Distributed notifications (CFNotificationCenter)
  - Screensaver ↔ Companion communication

**Target:** 3+ months

---

### v1.1.0 - Enhanced Features

**Goal:** Premium features and polish

- [ ] **Gold Sheep Authentication**
  - Account login (1280x720 content)
  - Keychain + iCloud sync for credentials

- [ ] **Auto-Updates**
  - Sparkle framework integration
  - Update both companion and screensaver

- [ ] **Analytics**
  - Anonymous usage stats (opt-in)

**Target:** TBD

---

### v2.0.0 - Full Parity

**Goal:** Complete Electric Sheep experience on modern macOS

- [ ] **Distributed Rendering**
  - Receive render jobs from server
  - Execute flam3 renderer locally
  - Upload completed frames

- [ ] **Apple Silicon Optimization**
  - Universal Binary (Intel + ARM64)
  - GPU acceleration exploration

- [ ] **Homebrew Formula**
  - Cask for easy installation
  - Auto-update integration

---

## Future Enhancements (Post v2.0)

- [ ] 4K/8K resolution support (local rendering)
- [ ] Infinidream integration (1080p content)
- [ ] tvOS Apple TV app
- [ ] Local sheep generation (no server dependency)

---

## How to Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to help with any milestone.

## Progress Tracking

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 0: Planning | Complete | 100% |
| Phase 1: Research | **Complete** | 100% |
| Phase 2: Companion App | Ready to Start | 0% |
| Phase 3: Screensaver | Blocked by Phase 2 | 0% |
| Phase 4: IPC | Blocked by Phase 2 | 0% |
| Phase 5: Server | Blocked by Phase 2 | 0% |
