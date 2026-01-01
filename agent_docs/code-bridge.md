# Objective-C ↔ C++ Bridge Layer

## Overview

Electric Sheep bridges Objective-C UI code to C++ backend logic via `ESScreensaver.cpp`. This file exports C functions callable from Objective-C.

## Bridge File

**File:** `client_generic/MacBuild/ESScreensaver.cpp` (309 lines)

## Global State

```cpp
// The main client instance
CElectricSheep_Mac gClient;
```

## Exported Functions

All functions use `extern "C"` for Objective-C compatibility.

### Lifecycle

```cpp
// Get application bundle reference
CFBundleRef CopyDLBundle_ex(void);

// Start screensaver with dimensions
bool ESScreensaver_Start(bool _bPreview, uint32 _width, uint32 _height);

// Process one frame (called from animation thread)
bool ESScreensaver_DoFrame(void);

// Stop screensaver
void ESScreensaver_Stop(void);

// Check if stopped
bool ESScreensaver_Stopped(void);

// Cleanup
void ESScreensaver_Deinit(void);

// Resize handling
void ESScreensaver_ForceWidthAndHeight(uint32 _width, uint32 _height);
```

### OpenGL Context

```cpp
// Register OpenGL context from ESOpenGLView
void ESScreenSaver_AddGLContext(void *_glContext);
```

Usage in ESScreensaverView.m:
```objc
ESScreenSaver_AddGLContext((CGLContextObj)[[glView openGLContext] CGLContextObj]);
```

### Settings I/O

```cpp
// Read settings from C++ storage
CFStringRef ESScreensaver_CopyGetStringSetting(const char *url, const char *defval);
SInt32 ESScreensaver_GetIntSetting(const char *url, const SInt32 defval);
bool ESScreensaver_GetBoolSetting(const char *url, const bool defval);
double ESScreensaver_GetDoubleSetting(const char *url, const double defval);

// Write settings to C++ storage
void ESScreensaver_SetStringSetting(const char *url, const char *val);
void ESScreensaver_SetIntSetting(const char *url, const SInt32 val);
void ESScreensaver_SetBoolSetting(const char *url, const bool val);
void ESScreensaver_SetDoubleSetting(const char *url, const double val);
```

Settings use URL-like keys:
- `settings.player.player_fps`
- `settings.player.DisplayMode`
- `settings.content.use_proxy`

### Storage

```cpp
// Initialize client storage (call before reading settings)
void ESScreensaver_InitClientStorage(void);

// Cleanup storage
void ESScreensaver_DeinitClientStorage(void);

// Get root directory path
CFStringRef ESScreensaver_CopyGetRoot(void);
```

### Input Events

```cpp
// Append keyboard event (for voting)
void ESScreensaver_AppendKeyEvent(UInt32 keyCode);
```

Key code mapping in implementation:
```cpp
switch (keyCode) {
    case 0x7E: code = KEY_UP;      // Vote up
    case 0x7D: code = KEY_DOWN;    // Vote down
    case 0x7B: code = KEY_LEFT;    // Previous
    case 0x7C: code = KEY_RIGHT;   // Next
    case 0x31: code = KEY_SPACE;   // Skip
    // ... more mappings
}
```

### Utility Functions

```cpp
// Get cache size in MB
size_t ESScreensaver_GetFlockSizeMBs(const char *mpegpath, int sheeptype);

// Parse role from server XML response
CFStringRef ESScreensaver_CopyGetRoleFromXML(const char *xml);

// Get version string
CFStringRef ESScreensaver_GetVersion(void);

// Set update availability
void ESScreensaver_SetUpdateAvailable(const char *verinfo);
```

## Implementation Details

### CopyDLBundle_ex()

Uses `dladdr()` to find the shared library path, then walks up the directory tree to locate the bundle:

```cpp
Dl_info info;
dladdr((const void *)CopyDLBundle_ex, &info);
// Traverse upward to find .app or .saver bundle
```

### ESScreensaver_Start()

1. Get player instance: `g_Player()`
2. Set dimensions: `DisplayOutput::CMacGL::SetDefaultWidthAndHeight()`
3. Initialize client: `gClient.Startup()`

### ESScreensaver_DoFrame()

```cpp
bool ESScreensaver_DoFrame(void) {
    return gClient.Update();
}
```

This calls into the main C++ update loop which:
- Fetches/downloads sheep
- Decodes video frames
- Renders to OpenGL
- Handles input events

## Type Conversions

| Objective-C | C++ |
|-------------|-----|
| NSString* | std::string |
| CFStringRef | std::string |
| BOOL | bool |
| NSInteger | SInt32 |
| double | double |

Conversion helpers in bridge:
```cpp
// CFString to std::string
std::string cfstring_to_string(CFStringRef cf) {
    CFIndex length = CFStringGetLength(cf);
    char *buffer = new char[length + 1];
    CFStringGetCString(cf, buffer, length + 1, kCFStringEncodingUTF8);
    std::string result(buffer);
    delete[] buffer;
    return result;
}
```

## Companion App Bridge Considerations

For the companion app (Swift):

1. **Keep Objective-C++ bridge** - Swift can call Objective-C
2. **Create Swift wrappers** for frequently used functions
3. **Consider pure Swift reimplementation** for networking (simpler than bridging libcurl)
4. **Bridge only for flam3 renderer** if distributed rendering needed
