# Networking Protocol

## Overview

Electric Sheep uses libcurl for all HTTP communication. The networking layer is in `client_generic/Networking/Networking.cpp` (13,163 lines).

## Server Infrastructure

| Server | IP | Purpose |
|--------|---|---------|
| `*.sheepserver.net` | 173.255.253.19 | Primary operations |
| `*.us.archive.org` | 207.241.*.* | Free sheep CDN |
| `d100rc88eim93q.cloudfront.net` | 54.192.55.139 | Gold sheep CDN |

## API Endpoints

### 1. Server Redirection
```
GET {REDIRECT_SERVER}/query.php?q=redir&u={username}&p={password}&v={version}&i={uniqueID}
```
**Response:** XML with server endpoints
```xml
<query>
  <redir host="sheep.example.com" vote="vote.example.com" render="render.example.com" role="gold"/>
</query>
```
Cache duration: 24 hours

### 2. Sheep List
```
GET {serverName}/cgi/list?v={CLIENT_VERSION}&u={uniqueID}

Example: v2d7c.sheepserver.net/cgi/list?v=OSX_C_1.0.0&u=550e8400-e29b-41d4
```
- Version string: `OSX_C_1.0.0` ('C' prefix distinguishes companion from legacy client)
**Response:** gzip-compressed XML
```xml
<list gen="42">
  <sheep id="1234" type="0" time="1609459200" size="5242880"
         rating="85" first="1230" last="1235" state="done"
         url="http://server.net/sheep/1234.avi" />
  <message>Server message</message>
  <error type="unauthenticated">Auth failed</error>
</list>
```
- `gen` < 10000 = normal sheep, >= 10000 = gold sheep
- `first`/`last` = transition link IDs for morphing
- `state="expunge"` = delete local copy

### 3. Sheep Download
```
GET {sheep->URL()}
Example: http://server.net/sheep/00042=01234=01230=01235.avi
```
File saved as: `{mpegPath}/{gen}={id}={first}={last}.avi`

### 4. Genome Request (for rendering)
```
GET {renderServerName}/cgi/get?n={nickName}&w={userUrl}&v={version}&u={uniqueID}&r={rating}&c={cores}
```
**Response:** gzip-compressed FLAM3 genome XML

### 5. Vote Submission
```
GET {voteServerName}/cgi/vote.cgi?id={sheep_id}&vote={vote}&u={uuid}

Example: v2d7c.sheepserver.net/cgi/vote.cgi?id=12345&vote=1&u=550e8400-e29b-41d4
```
- `vote`: `1` (up) or `-1` (down)
- Response: 302 redirect (success) or 401 (auth failed)
- Offline: Queue locally, retry once when network returns

### 6. Frame Upload (distributed rendering)
```
PUT {serverName}/cgi/put?j={jobId}&id={sheepId}&s={fileSize}&g={generation}&v={version}&u={uniqueID}
Content: Raw JPEG frame data
```

## Authentication

Password hashing: `MD5(nickname + 'sh33p' + username)`

User roles:
- `error` - Authentication failed
- `none` - No account
- `registered` - Basic account
- `member` - Paid member
- `gold` - Premium access

## Network Classes

### CCurlTransfer (Base)
```cpp
Perform(url)                    // Synchronous HTTP request
InterruptiblePerform()          // Async with select() polling
customProgressCallback()        // Update CManager::UpdateProgress()
```

### CFileDownloader
```cpp
Perform(url)                    // Download to m_Data buffer
Save(outputPath)                // Write buffer to disk
// Pre-allocates 10MB buffer
```

### CFileUploader
```cpp
PerformUpload(url, file, size)  // Upload file via PUT
```

## Security Notes

SSL verification is **disabled** for `sheepserver.net` (self-signed certificate):
```cpp
curl_easy_setopt(m_pCurl, CURLOPT_SSL_VERIFYHOST, 0);
curl_easy_setopt(m_pCurl, CURLOPT_SSL_VERIFYPEER, 0);
```

**Why this is acceptable:**
- Not distributed via App Store (direct download + Homebrew)
- Matches existing client behavior
- No sensitive data transmitted
- SSL enabled for CDNs (archive.org, cloudfront)

## Retry Logic

- Success: Reset to `TIMEOUT` (600s)
- Failure: Exponential backoff up to `MAX_TIMEOUT` (86400s / 1 day)
- Formula: `sleep = Clamp(sleep * 2, 600, 86400)`

## Live Validation (January 2026)

Servers verified operational:

| Endpoint | Status | Notes |
|----------|--------|-------|
| `community.sheepserver.net` | **UP** | Self-signed SSL (use HTTP or --insecure) |
| `v3d0.sheepserver.net` | **UP** | Returned by redirect query |
| `archive.org` | **UP** | CDN for sheep videos |

### Redirect Response
```
GET http://community.sheepserver.net/query.php?q=redir&v=3.0.3&i=test
```
Returns:
```xml
<query><redir role="none" host="http://v3d0.sheepserver.net/" vote="http://v3d0.sheepserver.net/" render="http://v3d0.sheepserver.net/"/></query>
```

### Sheep List Response
```
GET http://v3d0.sheepserver.net/cgi/list?v=3.0.3&u=test | gunzip
```
Returns gzip-compressed XML with current generation 248:
```xml
<list gen="248" size="800 592" retry="600">
  <sheep id="37653" type="0" state="done" time="1767023148" size="1358314"
         rating="2" first="37653" last="37653"
         url="http://www.archive.org/download/electricsheep-flock-248-37500-3/00248=37653=37653=37653.avi"/>
</list>
```

### Download Verification
Sample download confirmed:
- URL: `http://www.archive.org/download/electricsheep-flock-248-37500-3/00248=37653=37653=37653.avi`
- Size: 1,358,314 bytes (matches XML)
- Format: RIFF/AVI, H.264 video, 800x592 @ 30fps
