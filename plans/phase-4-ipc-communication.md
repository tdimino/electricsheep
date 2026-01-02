# Phase 4: Inter-Process Communication

## Objective

Establish reliable communication between the companion app and the sandboxed screensaver using macOS distributed notifications (CFNotificationCenter).

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Payload mechanism | Notification name suffix | Encode data as `org.electricsheep.SheepPlaying.248=12345=0=240` |
| Vote race handling | Queue votes | Queue second vote, process after first completes |
| Global hotkey API | HotKey (Swift) | Modern Swift package by @soffes, lightweight, MIT license |
| Vote overlay style | Corner arrow + fade | Fade in 0.3s → hold 1.5s → fade out 0.5s |
| Companion detection | Listen for broadcast | Companion broadcasts ESCompanionLaunched on startup |
| LRU tracking frequency | Once per sheep start | Fire once when sheep begins playing |
| Corrupted file priority | Immediate high-priority | Jump queue, download corrupted sheep immediately |
| Vote confirmation | Silent (screensaver only) | Only screensaver shows feedback overlay |
| Vote failure handling | Silent fail, no retry | Discard failed votes silently |
| Observer cleanup | In stopAnimation | Remove observers when screensaver stops |
| Debug logging | Hidden preference toggle | Enable verbose os_log when troubleshooting |
| Threading | Main thread (automatic) | CFNotificationCenter delivers callbacks on main thread |
| Screensaver verification | Trust ping/pong only | No additional process list checks needed |

## Chosen Approach: Distributed Notifications

### Why Distributed Notifications?

| Criteria | Distributed Notifications | File-Based | XPC Service |
|----------|--------------------------|------------|-------------|
| Complexity | Low | Low | High |
| Real-time | Yes | No (polling) | Yes |
| Sandbox compatible | Yes | Yes | Complex |
| Payload support | Limited | Full JSON | Full |
| Race conditions | None | Possible | None |
| Disk I/O | None | Yes | None |

**Decision:** Distributed notifications are the best balance of simplicity and real-time capability for our use case.

## Notification Protocol

### Companion → Screensaver

| Notification | Payload | Purpose |
|--------------|---------|---------|
| `ESPong` | none | Response to ping - companion is alive |
| `ESCompanionLaunched` | capabilities flags | Companion started, screensaver clears warning |
| `ESCacheUpdated` | none | New sheep available, reload cache |
| `ESVoteFeedback` | direction (suffix: `.up` or `.down`) | Show vote overlay |
| `ESQueryCurrent` | none | Request current sheep ID |

### Screensaver → Companion

| Notification | Payload | Purpose |
|--------------|---------|---------|
| `ESPing` | none | Check if companion is running (2s timeout) |
| `ESSheepPlaying` | sheep ID (suffix) | Currently displaying sheep |
| `ESPlaybackStarted` | sheep ID (suffix) | Update LRU timestamp |
| `ESCorruptedFile` | sheep ID (suffix) | Request re-download of corrupted file |

### Notification Names

```objc
// ESNotificationNames.h
extern NSString * const ESPingNotification;              // @"org.electricsheep.Ping"
extern NSString * const ESPongNotification;              // @"org.electricsheep.Pong"
extern NSString * const ESCompanionLaunchedNotification; // @"org.electricsheep.CompanionLaunched"
extern NSString * const ESCacheUpdatedNotification;      // @"org.electricsheep.CacheUpdated"
extern NSString * const ESVoteFeedbackNotification;      // @"org.electricsheep.VoteFeedback"
extern NSString * const ESQueryCurrentNotification;      // @"org.electricsheep.QueryCurrent"
extern NSString * const ESSheepPlayingNotification;      // @"org.electricsheep.SheepPlaying"
extern NSString * const ESPlaybackStartedNotification;   // @"org.electricsheep.PlaybackStarted"
extern NSString * const ESCorruptedFileNotification;     // @"org.electricsheep.CorruptedFile"
```

### Payload Encoding (Notification Name Suffix)

Since CFNotificationCenter doesn't support userInfo dictionaries, encode payloads as notification name suffixes:

```objc
// Posting with payload
NSString *notificationName = [NSString stringWithFormat:@"%@.%@",
    ESSheepPlayingNotification, sheepID];
CFNotificationCenterPostNotification(center, (__bridge CFStringRef)notificationName,
    NULL, NULL, true);

// Receiving with payload
// Observer registered for "org.electricsheep.SheepPlaying" prefix
// Parse sheepID from notification name after the prefix
```

**Examples:**
- `org.electricsheep.SheepPlaying.248=12345=0=240` - sheep ID in suffix
- `org.electricsheep.VoteFeedback.up` - vote direction
- `org.electricsheep.CompanionLaunched.voting=1,rendering=0` - capabilities

### Capabilities Flags (ESCompanionLaunched)

When companion broadcasts ESCompanionLaunched, include capabilities:

| Flag | Values | Purpose |
|------|--------|---------|
| `voting` | 0, 1 | Voting available (hotkeys registered) |
| `rendering` | 0, 1 | Distributed rendering active |
| `gold` | 0, 1 | Gold membership active (1280x720 content) |

Format: `org.electricsheep.CompanionLaunched.voting=1,rendering=0,gold=0`

## Tasks

### 4.1 Define Notification Protocol

- [ ] Create ESNotificationNames.h with notification constants
- [ ] Create ESNotificationParser.h for suffix encoding/decoding
- [ ] Document payload formats and capabilities flags
- [ ] Define notification behavior contracts

### 4.2 Companion App: Notification Center

```swift
class NotificationBridge {
    private let center = CFNotificationCenterGetDistributedCenter()
    private var pendingVotes: [VoteRequest] = []  // Vote queue
    private var isProcessingVote = false

    func startListening() {
        // Listen for screensaver notifications (prefix matching)
        observePrefix(ESSheepPlayingNotification) { [weak self] sheepID in
            self?.handleSheepPlaying(sheepID: sheepID)
        }
        observePrefix(ESPlaybackStartedNotification) { [weak self] sheepID in
            self?.handlePlaybackStarted(sheepID: sheepID)
        }
        observePrefix(ESCorruptedFileNotification) { [weak self] sheepID in
            self?.handleCorruptedFile(sheepID: sheepID)
        }
        observe(ESPingNotification) { [weak self] in
            self?.postPong()
        }
    }

    func broadcastLaunched(capabilities: Capabilities) {
        let suffix = "voting=\(capabilities.voting ? 1 : 0)," +
                     "rendering=\(capabilities.rendering ? 1 : 0)," +
                     "gold=\(capabilities.gold ? 1 : 0)"
        post("\(ESCompanionLaunchedNotification).\(suffix)")
    }

    func postVoteFeedback(direction: VoteDirection) {
        post("\(ESVoteFeedbackNotification).\(direction.rawValue)")
    }

    func handleCorruptedFile(sheepID: String) {
        // Immediate high-priority re-download
        DownloadManager.shared.priorityRedownload(sheepID)
    }
}
```

- [ ] Implement NotificationBridge class with prefix matching
- [ ] Implement vote queue (FIFO processing)
- [ ] Register observers on app launch
- [ ] Broadcast ESCompanionLaunched with capabilities on startup
- [ ] Handle ESPing → respond with ESPong
- [ ] Handle ESCorruptedFile → priority re-download

### 4.3 Screensaver: Notification Center

```objc
@interface ESNotificationHandler : NSObject
@property (nonatomic, assign) BOOL companionRunning;
@property (nonatomic, assign) BOOL votingAvailable;
@property (nonatomic, assign) BOOL debugLogging;

- (void)startListening;
- (void)stopListening;  // Call in stopAnimation
- (void)postSheepPlaying:(NSString *)sheepID;
- (void)postPlaybackStarted:(NSString *)sheepID;
- (void)postCorruptedFile:(NSString *)sheepID;
@end

@implementation ESNotificationHandler

- (void)startListening {
    CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();

    // Listen for companion launched (clears warning if companion starts later)
    CFNotificationCenterAddObserver(center, (__bridge const void *)(self),
        &handleCompanionLaunched,
        CFSTR("org.electricsheep.CompanionLaunched"),
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    // Listen for vote feedback (prefix match)
    CFNotificationCenterAddObserver(center, (__bridge const void *)(self),
        &handleVoteFeedback,
        CFSTR("org.electricsheep.VoteFeedback"),
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    // ... register other observers

    // Initial ping with 2s timeout
    [self postPing];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{
            if (!self.companionRunning) {
                [self showCompanionWarning];
            }
        });
}

- (void)stopListening {
    CFNotificationCenterRemoveEveryObserver(
        CFNotificationCenterGetDistributedCenter(),
        (__bridge const void *)(self));
}

- (void)postSheepPlaying:(NSString *)sheepID {
    NSString *name = [NSString stringWithFormat:@"org.electricsheep.SheepPlaying.%@", sheepID];
    [self postNotification:name];
    if (self.debugLogging) {
        os_log(OS_LOG_DEFAULT, "ESNotification: Posted SheepPlaying.%{public}@", sheepID);
    }
}

@end
```

- [ ] Create ESNotificationHandler class
- [ ] Implement startListening with all observers
- [ ] Implement stopListening (call in stopAnimation for cleanup)
- [ ] Implement 2s ping timeout with dispatch_after
- [ ] Listen for ESCompanionLaunched to clear warning after startup
- [ ] Parse capabilities from ESCompanionLaunched suffix
- [ ] Add debugLogging preference toggle

### 4.4 Global Hotkey Manager

```swift
import HotKey  // github.com/soffes/HotKey

class GlobalHotkeyManager {
    private var upHotKey: HotKey?
    private var downHotKey: HotKey?
    private let voteManager: VoteManager

    func register() {
        // Cmd+Up for upvote
        upHotKey = HotKey(key: .upArrow, modifiers: [.command])
        upHotKey?.keyDownHandler = { [weak self] in
            self?.voteManager.queueVote(direction: .up)
        }

        // Cmd+Down for downvote
        downHotKey = HotKey(key: .downArrow, modifiers: [.command])
        downHotKey?.keyDownHandler = { [weak self] in
            self?.voteManager.queueVote(direction: .down)
        }
    }

    func unregister() {
        upHotKey = nil
        downHotKey = nil
    }
}
```

**Note:** HotKey library may require Accessibility permission. Handle permission prompt gracefully.

- [ ] Add HotKey Swift package dependency
- [ ] Implement GlobalHotkeyManager
- [ ] Register Cmd+Up and Cmd+Down hotkeys
- [ ] Handle Accessibility permission request/denial
- [ ] Unregister on app quit

### 4.5 Voting Flow

```
User presses Cmd+Up (global hotkey)
         │
         ▼
┌─────────────────────┐
│   Companion App     │
│ Queue vote request  │
│ (if queue empty,    │
│  process immediately│
└──────────┬──────────┘
           │
           │ Post: ESQueryCurrent
           ▼
┌─────────────────────┐
│    Screensaver      │
│ (receives query)    │
└──────────┬──────────┘
           │
           │ Post: ESSheepPlaying.248=12345=0=240
           ▼
┌─────────────────────┐
│   Companion App     │
│ (receives sheep ID) │
│                     │
│ POST vote to server │
│ (silent fail if     │
│  network error)     │
└──────────┬──────────┘
           │
           │ Post: ESVoteFeedback.up
           ▼
┌─────────────────────┐
│    Screensaver      │
│ (shows ↑ overlay)   │
│                     │
│ Corner arrow:       │
│ - Fade in 0.3s      │
│ - Hold 1.5s         │
│ - Fade out 0.5s     │
└──────────┬──────────┘
           │
           │ Companion: process next queued vote (if any)
           ▼
```

**Vote Queue Behavior:**
- Votes are queued FIFO
- Only one vote processed at a time
- Each vote waits for server response before processing next
- Network failures: silent discard, process next in queue

- [ ] Implement VoteManager with queue
- [ ] Implement full voting flow
- [ ] Implement vote feedback overlay in screensaver (corner arrow)
- [ ] Arrow animation: fade in 0.3s → hold 1.5s → fade out 0.5s
- [ ] Green arrow for upvote, red arrow for downvote
- [ ] Silent failure on network error (no retry)

### 4.6 Companion Detection Flow

```
Screensaver starts
         │
         ▼
┌─────────────────────┐
│    Screensaver      │
│ 1. startListening() │
│ 2. Post: ESPing     │
│ 3. Start 2s timer   │
└──────────┬──────────┘
           │
           ├─── ESPong received within 2s ───┐
           │                                  │
           ▼                                  ▼
┌─────────────────────┐         ┌─────────────────────┐
│  Timer fires:       │         │  companionRunning   │
│  companionRunning   │         │       = YES         │
│       = NO          │         │  Cancel timer       │
│  Show subtle        │         │  Normal operation   │
│  warning message    │         │                     │
└─────────────────────┘         └─────────────────────┘
           │
           │ Continue playing cached sheep
           │
           ├─── Later: ESCompanionLaunched received ───┐
           │                                           │
           ▼                                           ▼
┌─────────────────────────────────────────────────────────┐
│  companionRunning = YES                                  │
│  Parse capabilities from suffix                          │
│  Clear warning message                                   │
│  votingAvailable = capabilities.voting                   │
└─────────────────────────────────────────────────────────┘
```

**Passive detection:** Instead of periodic re-pinging, screensaver listens for ESCompanionLaunched. If companion starts after screensaver, the broadcast clears the warning.

- [ ] Post ESPing on screensaver startup
- [ ] Implement 2s timeout with dispatch_after
- [ ] Set companionRunning flag based on ESPong response
- [ ] Show subtle corner warning if companion not detected
- [ ] Listen for ESCompanionLaunched to clear warning later
- [ ] Parse capabilities flags from ESCompanionLaunched
- [ ] Companion responds to ESPing with ESPong
- [ ] Companion broadcasts ESCompanionLaunched on startup

### 4.7 Corrupted File Handling

When screensaver detects a corrupted sheep file:
1. Screensaver posts `ESCorruptedFile.{sheepID}`
2. Companion receives and immediately queues high-priority re-download
3. Screensaver skips to next sheep

**Priority:** Corrupted file downloads jump to front of queue (immediate).

- [ ] Post ESCorruptedFile when file validation fails
- [ ] Companion: priorityRedownload() jumps queue
- [ ] Debounce rapid notifications (max 1 per sheep per 60s)

### 4.8 Playback Tracking (LRU)

When screensaver starts playing a sheep:
1. Screensaver posts `ESPlaybackStarted.{sheepID}` once at start
2. Companion receives and updates playback.json timestamp
3. Used for LRU cache eviction

**Frequency:** Once per sheep start only (not periodic).

- [ ] Post ESPlaybackStarted on each sheep start
- [ ] Update playback.json on companion side
- [ ] Debounce rapid notifications (max 1 per sheep per 10s)

### 4.9 Debug Logging

Hidden preference to enable verbose logging:

```objc
// ESNotificationHandler.m
- (void)logDebug:(NSString *)message {
    if (self.debugLogging) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,
            "ESNotification: %{public}@", message);
    }
}
```

**Preference key:** `ESDebugNotifications` (boolean, defaults to NO)

View logs: `log stream --predicate 'subsystem == "org.electricsheep"'`

- [ ] Add ESDebugNotifications preference
- [ ] Log all notification posts/receives when enabled
- [ ] Document how to view logs in Console.app

### 4.10 Observer Lifecycle

```objc
// ESScreensaverView.m

- (void)startAnimation {
    [super startAnimation];
    [self.notificationHandler startListening];
    // ...
}

- (void)stopAnimation {
    [self.notificationHandler stopListening];  // Remove all observers
    [super stopAnimation];
}
```

- [ ] Call startListening in startAnimation
- [ ] Call stopListening in stopAnimation
- [ ] Verify no observer leaks with Instruments

### 4.11 Testing

- [ ] Unit test notification posting/receiving
- [ ] Unit test payload encoding/decoding (name suffixes)
- [ ] Unit test vote queue behavior
- [ ] Integration test full voting flow
- [ ] Integration test companion detection (with/without companion)
- [ ] Test with screensaver in System Preferences preview
- [ ] Test with full-screen screensaver
- [ ] Test Accessibility permission flow for hotkeys
- [ ] Test debug logging toggle

## Risk Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Notification delivery loss | Medium | Low | Distributed notifications are reliable; log failures in debug mode |
| Accessibility permission denied | High | Medium | Gracefully disable hotkeys, show Settings guidance |
| Future macOS sandbox restrictions | High | Low | Monitor macOS betas; notifications work today |
| Hotkey conflicts with other apps | Low | Medium | Use uncommon modifier combo; document conflicts |
| Observer memory leaks | Medium | Low | Explicit cleanup in stopListening; verify with Instruments |

## Deliverables

- [ ] ESNotificationNames.h with all 9 notification constants
- [ ] ESNotificationParser.h for suffix encoding/decoding
- [ ] NotificationBridge class in companion (handles all incoming notifications)
- [ ] ESNotificationHandler class in screensaver (handles all incoming notifications)
- [ ] GlobalHotkeyManager with HotKey package
- [ ] VoteManager with queue and silent failure
- [ ] Full voting flow with corner arrow overlay
- [ ] Companion detection with passive ESCompanionLaunched listening
- [ ] Corrupted file high-priority re-download
- [ ] Playback tracking for LRU (once per sheep)
- [ ] Debug logging toggle

## Success Criteria

- [ ] Companion knows when screensaver starts/stops playing sheep
- [ ] Voting works via Cmd+Up/Down global hotkeys
- [ ] Vote feedback shows corner arrow on screensaver (0.3s in, 1.5s hold, 0.5s out)
- [ ] Votes queue properly (no lost votes during rapid pressing)
- [ ] LRU timestamps update on playback start
- [ ] Screensaver detects companion presence within 2s
- [ ] Screensaver clears warning when companion launches later
- [ ] Corrupted files trigger immediate high-priority re-download
- [ ] No message loss under normal conditions
- [ ] No observer leaks (verified with Instruments)
- [ ] Debug logging works when enabled

## Dependencies

- Phase 2 companion app with download manager
- Phase 3 screensaver with HUD overlay system
- HotKey Swift package (github.com/soffes/HotKey)
