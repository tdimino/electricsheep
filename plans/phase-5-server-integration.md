# Phase 5: Server Communication

## Objective

Implement full compatibility with Electric Sheep servers for downloading sheep, submitting votes, and authenticating Gold members. Distributed rendering deferred to v2.0.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| SSL verification | Disabled (match existing) | Server uses self-signed cert; not App Store, so acceptable |
| Distribution | Direct download + Homebrew | Maximum reach, avoids App Store SSL rejection |
| Anonymous users | Full functionality | Download and vote without account, just no Gold content |
| Download priority | Higher-rated first | Users see best content sooner |
| Expunge handling | After current playback | Wait for screensaver to finish, then delete |
| List refresh | Honor 1-hour TTL | Match existing client, server-friendly |
| Credentials | Keychain + optional iCloud | Default local, toggle for sync in preferences |
| Retry strategy | Exponential backoff | 10min → 24hr cap, match existing client |
| Server fallback | Yes, match existing | Resilient if primary auth server has issues |
| Gold cache | Separate directories | `free/` and `gold/` subdirs, clear separation |
| Distributed rendering | Defer to v2.0 | Focus MVP on download/playback/voting |
| Server messages | Menu bar submenu | Non-intrusive, "Server Message" item when present |
| Client ID | UUID on first launch | Random UUID in UserDefaults, privacy-friendly |
| Offline mode | Full offline support | Queue votes, play cache, sync when back online |
| Offline votes | Queue when offline | Retry once when network returns |
| Version string | `OSX_C_1.0.0` | 'C' prefix distinguishes companion in server logs |

## Server Infrastructure

| Server | Hostname | Purpose | Priority |
|--------|----------|---------|----------|
| Redirect/Auth | `community.sheepserver.net` | Authentication, server discovery | MVP |
| Main Server | `v2d7c.sheepserver.net` | Sheep list, downloads | MVP |
| Archive CDN | `*.us.archive.org` | Free sheep hosting | MVP |
| CloudFront CDN | `d100rc88eim93q.cloudfront.net` | Gold sheep hosting | v1.1 |

## Protocol Details

### Transport
- **HTTP/HTTPS** on ports 80/443
- **SSL verification disabled** (self-signed cert on sheepserver.net)
- **Max redirects**: 5 hops (CURLOPT_MAXREDIRS=5)
- **Timeout**: 600 seconds

### Authentication
- **Method**: HTTP Basic Auth (RFC 2617)
- **Header**: `Authorization: Basic base64(username:password)`
- **Credentials**: URL-encoded nickname and password

### Data Formats
- **Sheep list**: gzip-compressed XML
- **Video files**: AVI container with MPEG video
- **File naming**: `{generation}={id}={first}={last}.avi`

## API Endpoints

### 1. Server Discovery (Redirect)

**Endpoint**: `GET https://community.sheepserver.net/query.php`

**Parameters**:
| Param | Value | Description |
|-------|-------|-------------|
| `q` | `redir` | Query type |
| `u` | `{nickname}` | URL-encoded username |
| `p` | `{password}` | URL-encoded password |
| `v` | `OSX_C_1.0.0` | Client version |
| `i` | `{uuid}` | Unique client ID (16+ chars) |

**Example**:
```
https://community.sheepserver.net/query.php?q=redir&u=mynick&p=mypass&v=OSX_C_1.0.0&i=550e8400-e29b-41d4
```

**Response** (XML):
```xml
<?xml version="1.0"?>
<query>
  <redir
    host="v2d7c.sheepserver.net"
    vote="v2d7c.sheepserver.net"
    render="render.sheepserver.net"
    role="anonymous|registered|admin"
  />
</query>
```

**Roles**:
| Role | Description |
|------|-------------|
| `anonymous` | No account, full access except Gold |
| `registered` | Valid login, full access |
| `admin` | Administrative access |

**HTTP Status Codes**:
- 200: Success
- 401: Authentication failed (trigger server fallback)
- 304: Not modified (cached response valid)

---

### 2. Sheep List

**Endpoint**: `GET {host}/cgi/list`

**Parameters**:
| Param | Value | Description |
|-------|-------|-------------|
| `v` | `OSX_C_1.0.0` | Client version |
| `u` | `{uuid}` | Unique client ID |

**Example**:
```
v2d7c.sheepserver.net/cgi/list?v=OSX_C_1.0.0&u=550e8400-e29b-41d4
```

**Response** (gzip XML):
```xml
<?xml version="1.0"?>
<list gen="248">
  <sheep
    id="12345"
    type="0"
    time="1699876543"
    size="2457600"
    rating="42"
    first="11111"
    last="22222"
    state="done"
    url="https://archive.org/sheep/248=12345=11111=22222.avi"
  />
  <sheep state="expunge" id="99999" ... />
  <message>Server maintenance tonight at 2AM UTC</message>
  <error type="unauthenticated">Please register for Gold access</error>
</list>
```

**Sheep States**:
| State | Action |
|-------|--------|
| `done` | Available for download |
| `expunge` | Delete from cache (after playback) |
| `pending` | Not yet available |

**Generation Ranges**:
| Range | Content |
|-------|---------|
| 0-9999 | Free sheep (640x480) |
| 10000+ | Gold sheep (1280x720) |

**Cache TTL**: 1 hour (3600 seconds) - honor server's MIN_READ_INTERVAL

---

### 3. Sheep Download

**URL**: From `<sheep url="..."/>` in list

**Request**:
```
GET {url}
Authorization: Basic base64(username:password)
```

**Response**:
- 200: AVI file data
- 401: Auth failed (trigger fallback)
- 404: File not found (skip)
- 5xx: Server error (retry with backoff)

**Verification**:
- Downloaded size must match `<sheep size="..."/>` from list
- On mismatch: delete partial file, retry

**Local Storage**:
```
~/Library/Application Support/ElectricSheep/
├── sheep/
│   ├── free/                    # Free sheep (gen 0-9999)
│   │   └── 248=12345=11111=22222.avi
│   └── gold/                    # Gold sheep (gen 10000+)
│       └── 10248=67890=33333=44444.avi
├── downloads/                   # In-progress downloads (.tmp)
└── metadata/                    # Sheep metadata JSON
```

---

### 4. Vote Submission

**Endpoint**: `GET {vote_server}/cgi/vote.cgi`

**Parameters**:
| Param | Value | Description |
|-------|-------|-------------|
| `id` | `{sheep_id}` | Sheep ID to vote on |
| `vote` | `-1` or `1` | Negative or positive vote |
| `u` | `{uuid}` | Unique client ID |

**Example**:
```
v2d7c.sheepserver.net/cgi/vote.cgi?id=12345&vote=1&u=550e8400-e29b-41d4
```

**Response**:
- 302: Redirect (normal success)
- 200: Success (alternate)
- 401: Auth failed

**Behavior**:
- Online: Submit immediately, silent fail on error
- Offline: Queue vote, retry once when network returns

---

## Tasks

### 5.1 Client Identification

```swift
class ClientIdentity {
    static var uniqueID: String {
        if let id = UserDefaults.standard.string(forKey: "ESClientUUID") {
            return id
        }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: "ESClientUUID")
        return id
    }

    static let version = "OSX_C_1.0.0"
}
```

- [ ] Generate UUID on first launch
- [ ] Store in UserDefaults
- [ ] Include in all server requests

### 5.2 Server Discovery

```swift
class ServerDiscovery {
    private let redirectURL = "https://community.sheepserver.net/query.php"

    func discover(credentials: Credentials?) async throws -> ServerConfig {
        var params = [
            "q": "redir",
            "v": ClientIdentity.version,
            "i": ClientIdentity.uniqueID
        ]
        if let creds = credentials {
            params["u"] = creds.nickname.urlEncoded
            params["p"] = creds.password.urlEncoded
        }
        // Fetch and parse XML response
        // Return ServerConfig with host, vote, render, role
    }
}
```

- [ ] Implement redirect query
- [ ] Parse XML response
- [ ] Extract server hostnames and role
- [ ] Cache discovery result (refresh on 401)

### 5.3 Sheep List Fetching

```swift
class SheepListFetcher {
    private var cachedList: SheepList?
    private var lastFetch: Date?
    private let minInterval: TimeInterval = 3600  // 1 hour

    func fetch(from server: String) async throws -> SheepList {
        // Check cache TTL
        if let cached = cachedList, let last = lastFetch,
           Date().timeIntervalSince(last) < minInterval {
            return cached
        }

        // Fetch gzip XML from server
        let url = "\(server)/cgi/list?v=\(ClientIdentity.version)&u=\(ClientIdentity.uniqueID)"
        let data = try await fetchGzip(url)
        let list = try parseSheepListXML(data)

        // Handle server message
        if let message = list.message {
            NotificationCenter.default.post(name: .serverMessage, object: message)
        }

        cachedList = list
        lastFetch = Date()
        return list
    }
}
```

- [ ] Implement gzip decompression
- [ ] Parse sheep list XML
- [ ] Honor 1-hour cache TTL
- [ ] Extract server messages
- [ ] Handle `<error>` elements

### 5.4 Download Manager

```swift
class DownloadManager {
    private var queue: [Sheep] = []
    private var retryBackoff: TimeInterval = 600  // Start at 10 minutes
    private let maxBackoff: TimeInterval = 86400  // Cap at 24 hours

    func queueDownloads(from list: SheepList) {
        // Filter to state="done", not in cache
        // Sort by rating (highest first)
        // Add to queue
    }

    func download(_ sheep: Sheep) async throws -> URL {
        let destDir = sheep.generation >= 10000 ? "gold" : "free"
        let filename = "\(sheep.generation)=\(sheep.id)=\(sheep.first)=\(sheep.last).avi"
        let destURL = cacheURL.appendingPathComponent(destDir).appendingPathComponent(filename)

        // Download to .tmp, verify size, rename
        let tmpURL = downloadsURL.appendingPathComponent(filename + ".tmp")
        try await downloadWithProgress(sheep.url, to: tmpURL)

        // Verify size
        let attrs = try FileManager.default.attributesOfItem(atPath: tmpURL.path)
        guard (attrs[.size] as? Int) == sheep.size else {
            try? FileManager.default.removeItem(at: tmpURL)
            throw DownloadError.sizeMismatch
        }

        try FileManager.default.moveItem(at: tmpURL, to: destURL)
        return destURL
    }

    func handleError(_ error: Error) {
        // Exponential backoff: 10min → 20min → 40min → ... → 24hr cap
        retryBackoff = min(retryBackoff * 2, maxBackoff)
        scheduleRetry(after: retryBackoff)
    }
}
```

- [ ] Implement download queue sorted by rating
- [ ] Download to .tmp, verify size, rename
- [ ] Separate free/ and gold/ directories
- [ ] Exponential backoff on failure (10min → 24hr)
- [ ] Resume interrupted downloads
- [ ] Post ESCacheUpdated notification on new sheep

### 5.5 Vote Submission

```swift
class VoteSubmitter {
    private var offlineQueue: [(sheepID: String, vote: Int)] = []

    func submit(sheepID: String, vote: Int) async {
        guard NetworkMonitor.shared.isConnected else {
            offlineQueue.append((sheepID, vote))
            return
        }

        let url = "\(serverConfig.voteServer)/cgi/vote.cgi?id=\(sheepID)&vote=\(vote)&u=\(ClientIdentity.uniqueID)"
        do {
            _ = try await fetch(url)
        } catch {
            // Silent fail - match Phase 4 decision
        }
    }

    func syncOfflineVotes() async {
        guard NetworkMonitor.shared.isConnected else { return }
        for item in offlineQueue {
            await submit(sheepID: item.sheepID, vote: item.vote)
        }
        offlineQueue.removeAll()
    }
}
```

- [ ] Submit vote via GET request
- [ ] Silent fail on error (Phase 4 decision)
- [ ] Queue votes when offline
- [ ] Retry queued votes once when network returns
- [ ] Integrate with Phase 4 VoteManager

### 5.6 Expunge Handling

```swift
class ExpungeHandler {
    private var pendingExpunge: Set<String> = []

    func markForExpunge(_ sheepIDs: [String]) {
        pendingExpunge.formUnion(sheepIDs)
    }

    func handlePlaybackEnded(sheepID: String) {
        if pendingExpunge.contains(sheepID) {
            deleteFromCache(sheepID)
            pendingExpunge.remove(sheepID)
        }
    }
}
```

- [ ] Parse state="expunge" from sheep list
- [ ] Track pending expunge set
- [ ] Delete after screensaver finishes playing
- [ ] Listen for ESPlaybackStarted to know when safe

### 5.7 Server Fallback

```swift
class ServerFallback {
    private var servers: [String] = [
        "v2d7c.sheepserver.net",
        "v2d6c.sheepserver.net",  // Backup
    ]
    private var currentIndex = 0

    func onAuthFailure() {
        currentIndex = (currentIndex + 1) % servers.count
        // Retry with next server
    }
}
```

- [ ] Maintain list of fallback servers
- [ ] Rotate on 401 response
- [ ] Reset to primary on successful auth

### 5.8 Gold Authentication

```swift
class GoldAuthManager {
    func storeCredentials(_ creds: Credentials, syncToiCloud: Bool) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "org.electricsheep.companion",
            kSecAttrAccount as String: creds.nickname,
            kSecValueData as String: creds.password.data(using: .utf8)!,
            kSecAttrSynchronizable as String: syncToiCloud
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
```

- [ ] Store credentials in Keychain
- [ ] Optional iCloud sync toggle
- [ ] Retrieve on app launch
- [ ] Clear on logout

### 5.9 Offline Mode

```swift
class OfflineManager {
    @Published var isOffline = false

    init() {
        NetworkMonitor.shared.onStatusChange = { [weak self] connected in
            self?.isOffline = !connected
            if connected {
                self?.syncPendingChanges()
            }
        }
    }

    func syncPendingChanges() async {
        await VoteSubmitter.shared.syncOfflineVotes()
        await DownloadManager.shared.resumeDownloads()
    }
}
```

- [ ] Monitor network connectivity
- [ ] Track offline state
- [ ] Sync votes when back online
- [ ] Resume downloads when back online
- [ ] Show offline indicator in menu bar

### 5.10 Server Messages

```swift
class ServerMessageHandler {
    @Published var currentMessage: String?

    func handle(message: String?) {
        currentMessage = message
        // Message appears in menu bar dropdown
    }
}
```

- [ ] Parse `<message>` from sheep list
- [ ] Store current message
- [ ] Display in menu bar submenu
- [ ] Clear when no message in list

### 5.11 SSL Configuration

```swift
// In URLSession configuration
class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept self-signed certificates for sheepserver.net
        if challenge.protectionSpace.host.contains("sheepserver.net") {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
```

- [ ] Disable SSL verification for sheepserver.net only
- [ ] Keep verification for CDNs (archive.org, cloudfront)
- [ ] Document for notarization review

### 5.12 Testing

- [ ] Unit test XML parsing (sheep list, redirect response)
- [ ] Unit test download queue sorting by rating
- [ ] Unit test exponential backoff logic
- [ ] Unit test offline vote queuing
- [ ] Integration test with mock server
- [ ] Manual test against real sheepserver.net
- [ ] Test server fallback on 401

## Cache Structure

```
~/Library/Application Support/ElectricSheep/
├── sheep/
│   ├── free/                         # Free sheep (gen 0-9999)
│   │   ├── 248=12345=11111=22222.avi
│   │   └── 248=67890=33333=44444.avi
│   └── gold/                         # Gold sheep (gen 10000+)
│       └── 10248=99999=55555=66666.avi
├── downloads/                        # In-progress (.tmp files)
├── metadata/                         # Sheep metadata JSON
├── lists/
│   ├── list_anonymous.xml           # Cached sheep list
│   └── list_registered.xml
├── playback.json                    # LRU tracking
├── config.json                      # User preferences
└── offline_votes.json               # Queued offline votes
```

## Risk Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Server unavailable | High | Low | Offline mode plays cached sheep; retry with backoff |
| Protocol changes | Medium | Low | Version check in requests; graceful degradation |
| SSL rejection by Apple | High | Medium | Not App Store; distribute via website + Homebrew |
| Self-signed cert expires | Medium | Low | SSL disabled; monitor for server changes |
| CDN changes | Medium | Low | URLs from server list, not hardcoded |
| Gold auth fails | Low | Low | Fallback to free content with message |

## Deliverables

- [ ] ClientIdentity class (UUID, version string)
- [ ] ServerDiscovery with redirect parsing
- [ ] SheepListFetcher with gzip + XML parsing
- [ ] DownloadManager with rating priority + backoff
- [ ] VoteSubmitter with offline queuing
- [ ] ExpungeHandler (delete after playback)
- [ ] ServerFallback on auth failure
- [ ] GoldAuthManager with Keychain + iCloud
- [ ] OfflineManager with network monitoring
- [ ] ServerMessageHandler for announcements
- [ ] SSL bypass for sheepserver.net
- [ ] Integration with Phase 2 ObjC++ bridge

## Success Criteria

- [ ] Redirect query returns server config
- [ ] Sheep list fetches and parses correctly
- [ ] Downloads prioritized by rating
- [ ] Files verified by size
- [ ] Votes reach server (when online)
- [ ] Offline votes sync when back online
- [ ] Expunged sheep deleted after playback
- [ ] Gold auth stores in Keychain
- [ ] Server messages appear in menu
- [ ] Fallback works on 401
- [ ] No server errors in logs

## Dependencies

- Phase 2 companion app with ObjC++ bridge
- Phase 4 IPC for ESCacheUpdated notification
- Network access for testing
- Test accounts (free + Gold)

## Version Milestones

| Version | Features |
|---------|----------|
| v1.0.0 MVP | Free sheep download, voting, offline mode |
| v1.1.0 | Gold authentication, 1280x720 content |
| v2.0.0 | Distributed rendering (frame upload) |
