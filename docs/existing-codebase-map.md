# Existing Codebase Map

## Repository Structure

```
electricsheep/
├── MANIFESTO.md            # Project vision and technical plan
├── ROADMAP.md              # Milestones and progress tracking
├── CONTRIBUTING.md         # How to contribute
├── README.md               # Project overview
├── CLAUDE.md               # Claude Code configuration
├── agent_docs/             # Claude Code documentation (progressive disclosure)
├── docs/                   # Developer documentation
├── plans/                  # Detailed phase plans
│
└── client_generic/         # Original Electric Sheep source
    ├── MacBuild/           # macOS Xcode project
    ├── ContentDownloader/  # Sheep downloading
    ├── Networking/         # HTTP client (libcurl)
    ├── ContentDecoder/     # Video decoding (FFmpeg)
    ├── DisplayOutput/      # Rendering (OpenGL/DirectX)
    ├── Client/             # Main application logic
    ├── Common/             # Shared utilities
    ├── TupleStorage/       # Key-value storage
    └── COPYING             # GPL2 license
```

## client_generic/ Directory

### MacBuild/ - macOS Platform Code
| File | Lines | Purpose |
|------|-------|---------|
| `ESScreensaverView.m` | 371 | Main screensaver controller |
| `ESScreensaverView.h` | 48 | Header for screensaver view |
| `ESConfiguration.m` | 596 | Settings/preferences UI |
| `ESConfiguration.h` | 83 | Header with IBOutlets |
| `ESScreensaver.cpp` | 309 | C++ bridge functions |
| `ESScreensaver.h` | 61 | Bridge function declarations |
| `ESWindow.m` | 196 | Window management |
| `ESOpenGLView.m` | 45 | OpenGL context setup |
| `main.m` | 15 | App entry point |
| `ElectricSheep.xcodeproj/` | - | Xcode project |
| `Frameworks/` | - | Sparkle.framework |
| `*.nib` | - | Interface Builder files |

### ContentDownloader/ - Sheep Acquisition
| File | Lines | Purpose |
|------|-------|---------|
| `SheepDownloader.cpp` | 1091 | Download loop, cache management |
| `SheepDownloader.h` | 78 | Downloader class |
| `Shepherd.cpp` | 851 | Paths, server config, flock management |
| `Shepherd.h` | 88 | Static configuration class |
| `SheepUploader.cpp` | 131 | Frame upload for rendering |
| `Sheep.cpp` | 195 | Sheep data model |
| `Sheep.h` | 87 | Sheep class definition |
| `ContentDownloader.cpp` | 247 | Singleton lifecycle |
| `SheepGenerator.cpp` | - | Flam3 render integration |

### Networking/ - HTTP Client
| File | Lines | Purpose |
|------|-------|---------|
| `Networking.cpp` | 13163 | libcurl wrapper implementation |
| `Networking.h` | 196 | CCurlTransfer, CFileDownloader, CFileUploader |
| `Download.cpp` | 110 | File download specialization |
| `Upload.cpp` | 62 | File upload specialization |

### ContentDecoder/ - Video Processing
| File | Lines | Purpose |
|------|-------|---------|
| `ContentDecoder.cpp` | 850+ | FFmpeg decode pipeline |
| `ContentDecoder.h` | 264 | Decoder class with threading |
| `Frame.h` | 215 | CVideoFrame container |
| `Frame.cpp` | ~100 | Frame implementation |

### DisplayOutput/ - Rendering
| File | Lines | Purpose |
|------|-------|---------|
| `DisplayOutput.h` | 206 | Abstract display interface |
| `Renderer/Renderer.h` | 191 | Abstract rendering API |
| `OpenGL/RendererGL.cpp` | 654 | OpenGL implementation |
| `OpenGL/TextureFlatGL.cpp` | 313 | OpenGL texture upload |
| `OpenGL/ESOpenGLView.m` | 45 | macOS OpenGL view |
| `DirectX/RendererDX.cpp` | 643 | DirectX 9 implementation |
| `Image.cpp` | 959 | Image format handling |

### Client/ - Application Logic
| File | Lines | Purpose |
|------|-------|---------|
| `Player.cpp` | 700+ | Main coordinator |
| `Player.h` | 260 | CPlayer class |
| `FrameDisplay.h` | 377 | Video frame rendering |
| `client_mac.h` | 290 | Mac-specific client |
| `ElectricSheep.h` | - | Base client class |

### Common/ - Utilities
| File | Purpose |
|------|---------|
| `BlockingQueue.h` | Threadsafe queue |
| `AlignedBuffer.h` | Memory alignment |
| `Log.h` | Logging system |
| `Timer.h` | Time utilities |
| `Exception.h` | Error handling |
| `md5.c` | MD5 hashing |

### TupleStorage/ - Persistence
| File | Purpose |
|------|---------|
| `TupleStorage.cpp` | Key-value storage implementation |
| `TupleStorage.h` | Storage interface |

## Key Entry Points

### Application Startup
```
main.m
└─ NSApplicationMain()
   └─ ESWindow.m: awakeFromNib
      └─ ESScreensaverView: initWithFrame:isPreview:
         └─ ESScreensaver_Start() [C++ bridge]
            └─ gClient.Startup()
```

### Screensaver Startup
```
System Preferences > Screen Saver > Electric Sheep
└─ ESScreensaverView: initWithFrame:isPreview:
   └─ startAnimation
      └─ ESScreensaver_Start() [C++ bridge]
         └─ gClient.Startup()
```

### Frame Loop
```
ESScreensaverView: _animationThread
└─ while (!stopped)
   └─ ESScreensaver_DoFrame()
      └─ gClient.Update()
         └─ g_Player().Display()->Update()
            └─ CFrameDisplay::Update()
```

### Download Loop
```
ContentDownloader::Startup()
└─ new boost::thread(SheepDownloader::shepherdCallback)
   └─ while (running)
      └─ findSheepToDownload()
         └─ getSheepList()
         └─ downloadSheep()
```

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| FFmpeg | 4.x | Video decoding |
| libcurl | 7.x | HTTP client |
| tinyXml | 2.x | XML parsing |
| zlib | 1.2.x | Decompression |
| Boost | 1.7x | Filesystem, threading |
| Sparkle | 1.x | Auto-updates |
| OpenGL | 2.1+ | Rendering |

## Build Requirements

- macOS 10.15+ (Catalina)
- Xcode 14+
- Command Line Tools
- Apple Developer certificate (for signing)
