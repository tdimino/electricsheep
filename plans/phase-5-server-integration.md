# Phase 5: Server Communication

## Objective

Implement full compatibility with Electric Sheep servers for downloading, voting, and distributed rendering contribution.

## Server Infrastructure

| Server | IP | Purpose | Priority |
|--------|---|---------|----------|
| `*.sheepserver.net` | 173.255.253.19 | Primary operations | MVP |
| `*.us.archive.org` | 207.241.*.* | Free sheep CDN | MVP |
| `d100rc88eim93q.cloudfront.net` | 54.192.55.139 | Gold sheep CDN | v0.2 |

## Protocol Details

- **Transport:** HTTP/HTTPS on ports 80/443
- **Data Format:** XML for genomes, MPEG2 for video
- **Authentication:** Account-based for Gold Sheep

## Tasks

### 5.1 Sheep Listing API

**Endpoint:** `GET /sheep/list`

**Reference:** `client_generic/ContentDownloader/Shepherd.cpp`

- [ ] Implement sheep list fetching
- [ ] Parse XML response
- [ ] Handle pagination
- [ ] Cache list locally

### 5.2 Sheep Download

**Endpoint:** `GET /sheep/{id}.mpg`

- [ ] Implement download with progress
- [ ] Resume interrupted downloads
- [ ] Verify file integrity
- [ ] Handle CDN redirects

### 5.3 Genome Fetching

**Endpoint:** `GET /genome/{id}.genome`

**Format:** XML with fractal flame parameters

```xml
<flame name="sheep_12345" size="1920 1080" ...>
  <xform weight="0.5" color="0.2" .../>
  ...
</flame>
```

- [ ] Parse genome XML
- [ ] Store alongside video files
- [ ] Use for metadata display

### 5.4 Vote Submission

**Endpoint:** `POST /vote`

**Payload:**
```json
{
  "sheep_id": "12345",
  "vote": 1,
  "user_id": "anonymous"
}
```

- [ ] Implement vote API call
- [ ] Queue votes when offline
- [ ] Confirm vote submission

### 5.5 Gold Sheep Authentication

**Endpoint:** `POST /auth/login`

- [ ] Secure credential storage in Keychain
- [ ] Token refresh mechanism
- [ ] Handle subscription expiry

### 5.6 Distributed Rendering (v1.0)

**Reference:** `client_generic/ContentDownloader/SheepUploader.cpp`

This is the distributed computing component where clients render frames.

- [ ] Receive render jobs from server
- [ ] Execute flam3 renderer
- [ ] Upload completed frames
- [ ] Track contribution statistics

### 5.7 Offline Mode

- [ ] Cache sheep list for offline use
- [ ] Queue votes for later submission
- [ ] Display cached sheep when offline
- [ ] Sync when connection restored

## API Documentation

### List Sheep

```
GET https://sheepserver.net/api/sheep
Headers:
  User-Agent: ElectricSheep/4.0 macOS

Response:
  <sheep>
    <item id="12345" url="..." size="..." />
    ...
  </sheep>
```

### Download Sheep

```
GET https://archive.org/sheep/12345.mpg
  or
GET https://cloudfront.../gold/12345.mpg (authenticated)
```

### Submit Vote

```
POST https://sheepserver.net/api/vote
Headers:
  Content-Type: application/json
  Authorization: Bearer {token}  (if Gold)

Body:
  {"sheep_id": "12345", "vote": 1}
```

## Deliverables

- [ ] Complete server API client
- [ ] Sheep downloading with verification
- [ ] Vote submission system
- [ ] Gold Sheep authentication
- [ ] Offline mode support

## Success Criteria

- [ ] Downloads work reliably
- [ ] Votes reach server
- [ ] Gold authentication works
- [ ] Offline mode graceful
- [ ] No server errors in logs

## Dependencies

- Phase 2 companion app foundation
- Network access for testing
- Test accounts (free + Gold)

## Security Considerations

- [ ] HTTPS for all connections
- [ ] Certificate pinning (optional)
- [ ] Keychain for credentials
- [ ] No plaintext passwords
