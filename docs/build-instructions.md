# Build Instructions

## Prerequisites

### System Requirements
- macOS 10.15 Catalina or later
- Xcode 14 or later
- Command Line Tools: `xcode-select --install`
- Apple Developer account (for code signing)

### Dependencies
The repository includes bundled dependencies in the Xcode project:
- FFmpeg (video decoding)
- libcurl (networking)
- tinyXml (XML parsing)
- zlib (decompression)
- Boost (filesystem, threading)
- Sparkle (auto-updates)

## Building the macOS Application

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/electricsheep.git
cd electricsheep
```

### 2. Open Xcode Project

```bash
open client_generic/MacBuild/ElectricSheep.xcodeproj
```

### 3. Configure Signing

1. Select the project in Xcode's navigator
2. Select the target (Electric Sheep or ElectricSheep.saver)
3. Go to "Signing & Capabilities"
4. Select your Team
5. Enable "Automatically manage signing"

### 4. Build

**Application:**
```
Product > Build (⌘B)
```

**Screensaver:**
1. Select "ElectricSheep.saver" scheme
2. Product > Build

### 5. Run

**Application:**
```
Product > Run (⌘R)
```

**Screensaver (install):**
1. Build the .saver target
2. Right-click on ElectricSheep.saver in Products
3. "Show in Finder"
4. Double-click to install
5. Open System Preferences > Screen Saver

## Build Configurations

### Debug
- Unoptimized code
- Full debug symbols
- Console logging enabled
- Use for development

### Release
- Optimized for performance
- Stripped symbols
- Notarization-ready
- Use for distribution

## Troubleshooting

### Missing Dependencies

If FFmpeg or other libraries are missing:

```bash
# Install via Homebrew
brew install ffmpeg libcurl boost

# Then update Xcode project paths:
# Build Settings > Header Search Paths
# Build Settings > Library Search Paths
```

### Code Signing Issues

```bash
# Check current signature
codesign -dv --verbose=4 /path/to/ElectricSheep.app

# Remove signature (for testing)
codesign --remove-signature /path/to/ElectricSheep.app

# Re-sign with your certificate
codesign -s "Developer ID Application: YOUR NAME" /path/to/ElectricSheep.app
```

### Screensaver Not Loading

1. Ensure signed with valid certificate
2. Check Console.app for errors from `ScreenSaverEngine`
3. Verify bundle structure:
   ```bash
   ls -la ~/Library/Screen\ Savers/ElectricSheep.saver/Contents/
   ```

### Network Issues (Sandbox)

Remember: The screensaver cannot access network in macOS 10.15+.
For testing network code, build and run as Application, not Screensaver.

## Companion App Build (Future)

The companion app will be a separate Xcode project:

```
companion/
├── ElectricSheepCompanion.xcodeproj
├── Sources/
│   ├── App/
│   ├── Networking/
│   └── UI/
└── Resources/
```

Build with:
```bash
cd companion
xcodebuild -scheme ElectricSheepCompanion -configuration Release
```

## Archive for Distribution

### 1. Create Archive
```
Product > Archive
```

### 2. Notarize
```bash
xcrun notarytool submit ElectricSheep.zip \
  --apple-id "your@email.com" \
  --team-id "XXXXXXXXXX" \
  --password "@keychain:AC_PASSWORD"
```

### 3. Staple
```bash
xcrun stapler staple ElectricSheep.app
```

### 4. Create DMG
```bash
hdiutil create -volname "Electric Sheep" \
  -srcfolder ElectricSheep.app \
  -ov -format UDZO \
  ElectricSheep.dmg
```

## CI/CD

GitHub Actions workflow (future):

```yaml
name: Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: xcodebuild -project client_generic/MacBuild/ElectricSheep.xcodeproj -scheme "Electric Sheep" -configuration Release
```
