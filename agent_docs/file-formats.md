# File Formats and Cache Structure

## Cache Directory

**Location:** `~/Library/Application Support/ElectricSheep/`

```
ElectricSheep/
├── mpeg/           # Downloaded sheep videos
├── xml/            # Server lists, genomes
├── jpeg/           # Rendered frames for upload
└── .instance-lock  # Process lock file
```

## Video Files (mpeg/)

### Filename Format
```
{generation}={id}={first}={last}.avi
```

**Examples:**
- `00001=00001=00000=00002.avi` - Normal sheep
- `10042=01234=01230=01235.avi` - Gold sheep (gen >= 10000)

**Components:**
- `generation` - 5-digit zero-padded generation number
- `id` - 5-digit sheep ID
- `first` - Transition-from sheep ID
- `last` - Transition-to sheep ID

### File States
- `.avi` - Complete video file
- `.avi.tmp` - Incomplete download (renamed on success)
- `.xxx` - Deleted marker (zero-length file)

### Video Format
- Container: AVI
- Codec: MPEG2
- Typical size: 1-20 MB per sheep

## XML Files (xml/)

### Sheep List
**File:** `list_{role}.xml` (e.g., `list_user.xml`, `list_gold.xml`)

```xml
<list gen="42">
  <sheep id="1234" type="0" time="1609459200" size="5242880"
         rating="85" first="1230" last="1235" state="done"
         url="http://server.net/sheep/1234.avi" />
  <sheep id="1235" type="0" state="expunge" />
  <message>Server maintenance tonight</message>
  <error type="unauthenticated">Invalid credentials</error>
</list>
```

**Attributes:**
| Attribute | Description |
|-----------|-------------|
| `id` | Unique sheep identifier |
| `type` | Sheep type (0 = animation) |
| `time` | Unix timestamp of creation |
| `size` | File size in bytes |
| `rating` | Popularity score (0-100) |
| `first` | Morph-from sheep ID |
| `last` | Morph-to sheep ID |
| `state` | "done" or "expunge" |
| `url` | Download URL |

### Genome Files
**File:** `cp_{generatorId}.xml`

FLAM3 genome format:
```xml
<flame name="sheep_12345" size="1920 1080" center="0 0"
       scale="200" rotate="0" quality="100" background="0 0 0">
  <xform weight="0.5" color="0.2" symmetry="0"
         coefs="1 0 0 1 0 0"
         variations="linear 1.0" />
  <xform weight="0.3" color="0.8" symmetry="0"
         coefs="0.5 0.5 -0.5 0.5 0.5 0"
         variations="sinusoidal 0.5 spherical 0.5" />
  <palette count="256">
    00000004080C101418...
  </palette>
</flame>
```

### Compressed Files
- `list.gzip` - Temporary compressed list (deleted after decompress)
- `cp_{id}.gzip` - Temporary compressed genome

## JPEG Files (jpeg/)

Rendered frames for distributed rendering upload.

**Format:** `frame_{generatorId}_{frameNum}.jpg`

## Cache Size Management

### Settings
- `settings.content.cache_size` - Normal sheep cache (MB)
- `settings.content.gold_cache_size` - Gold sheep cache (MB)
- Default: 2000 MB per type
- Value of 0 = unlimited

### Tracking
```cpp
Shepherd::s_ClientFlockBytes[0]  // Normal sheep bytes
Shepherd::s_ClientFlockBytes[1]  // Gold sheep bytes
```

### Deletion Priority
When cache exceeds limit, delete sheep by:
1. Lowest play count (from PlayCounter)
2. Oldest file write time (if tied)
3. 50% random factor between oldest/most-played

## Generation Types

```cpp
int getGenerationType() {
    return (generation() < 10000) ? 0 : 1;
}
// 0 = normal sheep (free)
// 1 = gold sheep (premium)
```

## Server Response Files

### Redirect Response
```xml
<query>
  <redir host="sheep.example.com"
         vote="vote.example.com"
         render="render.example.com"
         role="gold"/>
</query>
```

### Error Response
```xml
<error type="unauthenticated">Invalid username or password</error>
```

## File Validation

### On Download
1. Verify file size matches `sheep->fileSize()`
2. Rename from `.avi.tmp` to `.avi`
3. Update `Shepherd::addClientFlockBytes()`

### On Startup
- `Shepherd::getClientFlock()` scans `mpegPath`
- Builds inventory of all `.avi` files
- Calculates total bytes per generation type
- Validates filename format: `%d=%d=%d=%d.avi`
