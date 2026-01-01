# Server API Reference

## Server Infrastructure

| Server | Purpose | Priority |
|--------|---------|----------|
| `*.sheepserver.net` | Primary operations | MVP |
| `*.us.archive.org` | Free sheep CDN | MVP |
| `d100rc88eim93q.cloudfront.net` | Gold sheep CDN | v0.2 |

## Endpoints

### 1. Server Redirection

Get endpoint URLs based on user role.

```
GET {REDIRECT_SERVER}/query.php?q=redir&u={username}&p={password}&v={version}&i={uniqueID}
```

**Parameters:**
| Param | Description |
|-------|-------------|
| `u` | URL-encoded username |
| `p` | URL-encoded password hash |
| `v` | Client version (e.g., "3.0.3") |
| `i` | Unique installation ID |

**Response:**
```xml
<query>
  <redir host="sheep.sheepserver.net"
         vote="vote.sheepserver.net"
         render="render.sheepserver.net"
         role="gold"/>
</query>
```

**Roles:**
- `error` - Authentication failed
- `none` - No account
- `registered` - Basic account
- `member` - Paid member
- `gold` - Premium access

**Cache:** 24 hours

---

### 2. Sheep List

Get available sheep for download.

```
GET {serverName}/cgi/list?v={version}&u={uniqueID}
```

**Response:** gzip-compressed XML

```xml
<list gen="42">
  <sheep id="1234" type="0" time="1609459200" size="5242880"
         rating="85" first="1230" last="1235" state="done"
         url="http://server.net/sheep/00042=01234=01230=01235.avi" />
  <sheep id="1235" state="expunge" />
  <message>Server maintenance at 2:00 AM UTC</message>
  <error type="unauthenticated">Invalid credentials</error>
</list>
```

**Attributes:**
| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | int | Unique sheep ID |
| `type` | int | 0 = animation |
| `time` | unix | Creation timestamp |
| `size` | bytes | File size |
| `rating` | 0-100 | Popularity score |
| `first` | int | Transition-from ID |
| `last` | int | Transition-to ID |
| `state` | string | "done" or "expunge" |
| `url` | string | Download URL |

**Generation Types:**
- `gen < 10000` = Normal sheep (free)
- `gen >= 10000` = Gold sheep (premium)

**HTTP Codes:**
- `200` - Success (process list)
- `304` - Not Modified (use cached)
- `401` - Unauthorized (clear credentials)

**Cache:** 1 hour (`MIN_READ_INTERVAL`)

---

### 3. Sheep Download

Download a sheep video file.

```
GET {url from sheep list}
Example: GET http://archive.org/sheep/00042=01234=01230=01235.avi
```

**Response:** Raw MPEG2 video stream

**Filename Format:** `{generation}={id}={first}={last}.avi`

**Verification:**
- File size must match `size` attribute
- Saved with `.avi.tmp` extension during download
- Renamed to `.avi` on success

---

### 4. Genome Request

Get fractal flame genome for rendering.

```
GET {renderServerName}/cgi/get?n={nickName}&w={userUrl}&v={version}&u={uniqueID}&r={rating}&c={cores}
```

**Parameters:**
| Param | Description |
|-------|-------------|
| `n` | User nickname |
| `w` | User website URL |
| `v` | Client version |
| `u` | Unique ID |
| `r` | User rating |
| `c` | CPU core count |

**Response:** gzip-compressed FLAM3 XML

```xml
<flame name="sheep_12345" size="1920 1080" center="0 0"
       scale="200" rotate="0" quality="100" background="0 0 0">
  <xform weight="0.5" color="0.2" symmetry="0"
         coefs="1 0 0 1 0 0"
         variations="linear 1.0" />
  <palette count="256">
    00000004080C101418...
  </palette>
</flame>
```

---

### 5. Vote Submission

Submit a vote for a sheep.

```
POST {voteServerName}/vote
Content-Type: application/json

{
  "sheep_id": "12345",
  "vote": 1,
  "user_id": "anonymous"
}
```

**Vote Values:**
- `1` = Up vote
- `-1` = Down vote
- `0` = Neutral/reset

**Response:**
```json
{"status": "ok", "new_rating": 86}
```

---

### 6. Frame Upload

Upload rendered frame for distributed computing.

```
PUT {serverName}/cgi/put?j={jobId}&id={sheepId}&s={fileSize}&g={generation}&v={version}&u={uniqueID}
Content-Type: image/jpeg

[JPEG data]
```

**Headers:**
```
Expect:  (empty - disables 100-continue)
```

---

## Authentication

### Password Hashing

```
hash = MD5(nickname + "sh33p" + username)
```

Stored in Keychain on macOS.

### Credential Flow

1. User enters username/password in settings
2. App computes MD5 hash
3. Hash sent to server (never plaintext password)
4. Server returns role in redirect response

---

## Error Handling

### XML Errors

```xml
<error type="unauthenticated">Invalid username or password</error>
<error type="rate_limited">Too many requests</error>
<error type="server_error">Internal server error</error>
```

### Retry Logic

| Scenario | Action |
|----------|--------|
| Network error | Retry with exponential backoff (600s → 86400s) |
| 401 Unauthorized | Clear credentials, prompt re-login |
| 304 Not Modified | Use cached list |
| 5xx Server Error | Retry after 10 minutes |

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| List | 1 request / hour |
| Download | No limit (bandwidth throttled) |
| Vote | 1 vote / sheep / minute |
| Genome | On-demand |

---

## Security Notes

### Current Issues
- SSL verification disabled in client
- HTTP fallback allowed

### Recommendations
- Enable SSL verification
- Use HTTPS exclusively
- Implement certificate pinning
- Store credentials in Keychain only

---

## Live Server Status (January 2026)

All servers verified operational:

| Server | Status | Protocol |
|--------|--------|----------|
| `community.sheepserver.net` | UP | HTTP (self-signed SSL cert) |
| `v3d0.sheepserver.net` | UP | HTTP |
| `archive.org` | UP | HTTPS |

**Current Generation:** 248
**Video Resolution:** 800x592
**Video Format:** H.264 in AVI container

### Verified Workflow
1. Redirect query returns `v3d0.sheepserver.net`
2. List endpoint returns gzip XML with sheep metadata
3. Videos hosted on archive.org with expected naming pattern
4. Download returns valid AVI files matching reported sizes
