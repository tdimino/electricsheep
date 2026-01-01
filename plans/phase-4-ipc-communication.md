# Phase 4: Inter-Process Communication

## Objective

Establish reliable communication between the companion app and the sandboxed screensaver for status updates, vote forwarding, and coordination.

## Options Analysis

### Option A: File-Based Signaling (Recommended for MVP)

**Pros:**
- Simple to implement
- No special entitlements needed
- Easy to debug (just check files)
- Works across process restarts

**Cons:**
- Polling required (not real-time)
- Potential race conditions
- Disk I/O overhead

**Implementation:**

```
~/Library/Application Support/ElectricSheep/
├── active.flag          # Screensaver creates on start, deletes on stop
├── current_sheep.json   # Currently playing sheep info
├── vote.pending         # Vote request from screensaver
└── companion.status     # Companion app status
```

### Option B: XPC Service (Future Enhancement)

**Pros:**
- Real-time communication
- Type-safe protocol
- System-managed lifecycle

**Cons:**
- Complex setup
- May have sandbox restrictions
- Harder to debug

**Implementation:**

```swift
// XPC Protocol
@objc protocol SheepXPCProtocol {
    func requestNextSheep(reply: @escaping (URL?) -> Void)
    func submitVote(sheepId: String, vote: Int)
    func reportPlaybackStatus(sheepId: String, position: Double)
    func getCompanionStatus(reply: @escaping (Bool, Int) -> Void)
}
```

## Tasks (Option A - File-Based)

### 4.1 Define File Formats

**active.flag:**
```json
{
  "pid": 12345,
  "started": "2024-01-15T10:30:00Z",
  "display": "Main Display"
}
```

**current_sheep.json:**
```json
{
  "id": "sheep_12345",
  "file": "sheep/12345.mpg",
  "position": 45.2,
  "duration": 90.0
}
```

**vote.pending:**
```json
{
  "sheep_id": "sheep_12345",
  "vote": 1,
  "timestamp": "2024-01-15T10:31:00Z"
}
```

### 4.2 Companion App: File Watcher

- [ ] Watch for active.flag creation/deletion
- [ ] Read current_sheep.json periodically
- [ ] Process vote.pending and delete after handling
- [ ] Write companion.status on state changes

### 4.3 Screensaver: File Writer

- [ ] Create active.flag on startAnimation
- [ ] Update current_sheep.json on video change
- [ ] Write vote.pending when user votes (via companion app focus)
- [ ] Delete active.flag on stopAnimation

### 4.4 Error Handling

- [ ] Handle stale active.flag (process crash detection)
- [ ] Validate JSON before parsing
- [ ] Implement file locking to prevent race conditions
- [ ] Clean up orphaned files on launch

### 4.5 Voting Flow

Since screensaver can't receive keyboard input in sandbox:

1. User presses hotkey (companion app must be running)
2. Companion app writes vote to vote.pending
3. Or: Companion app reads current_sheep.json and submits vote
4. Companion app shows vote confirmation in menu bar

## Tasks (Option B - XPC, Future)

### 4.6 XPC Service Setup

- [ ] Create XPC service target in companion app
- [ ] Define protocol with @objc markers
- [ ] Implement service listener
- [ ] Handle connection lifecycle

### 4.7 Screensaver XPC Client

- [ ] Create XPC connection in screensaver
- [ ] Implement reconnection on failure
- [ ] Cache data locally if connection fails

## Deliverables

- [ ] File-based IPC implementation
- [ ] Companion app file watcher
- [ ] Screensaver file writer
- [ ] Error recovery mechanisms

## Success Criteria

- [ ] Companion knows when screensaver is active
- [ ] Current sheep info visible in companion menu
- [ ] Voting works through companion app
- [ ] No data loss on process crashes

## Dependencies

- Phase 2 companion app
- Phase 3 screensaver modifications
