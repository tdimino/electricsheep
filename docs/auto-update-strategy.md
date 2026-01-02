# Auto-Update Strategy

## Overview

Electric Sheep Companion uses **Sparkle 2** for automatic updates. This document covers setup, signing, and notarization requirements.

## Why Sparkle (Not Homebrew Auto-Update)

| Method | Pros | Cons |
|--------|------|------|
| **Sparkle** | Immediate updates, delta patches, user control | Requires hosting appcast |
| **Homebrew** | No hosting needed, trusted source | Slow update propagation, requires PR |

**Decision**: Use Sparkle for updates, Homebrew for initial discovery/install.

## Sparkle 2 Setup

### 1. Add Sparkle Package

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

Or in Xcode: File > Add Packages > `https://github.com/sparkle-project/Sparkle`

### 2. Configure Info.plist

```xml
<key>SUFeedURL</key>
<string>https://electricsheep.org/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY_HERE</string>

<key>SUEnableAutomaticChecks</key>
<true/>
```

### 3. Generate Signing Keys

```bash
# From Sparkle package artifacts
./bin/generate_keys

# Output:
# A key has been generated and saved in your keychain.
# Public key: pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=
```

- Private key stored in macOS Keychain
- Public key goes in `SUPublicEDKey` in Info.plist
- **Never lose the private key** - you can't sign updates without it

### 4. Set Up Updater Controller

**SwiftUI (Programmatic)**:
```swift
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}
```

**Menu Bar Integration**:
```swift
Button("Check for Updates...") {
    updaterController.updater.checkForUpdates()
}
```

## Signing & Notarization

### Requirements

1. **Apple Developer ID** - Required for notarization
2. **Hardened Runtime** - Required for notarization
3. **EdDSA Key** - For Sparkle update verification

### Build & Sign Workflow

```bash
# 1. Archive in Xcode
xcodebuild archive -scheme "Electric Sheep Companion" -archivePath build/ESCompanion.xcarchive

# 2. Export with Developer ID
xcodebuild -exportArchive -archivePath build/ESCompanion.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist

# 3. Create update archive (preserving symlinks)
cd build/export
ditto -c -k --sequesterRsrc --keepParent "Electric Sheep Companion.app" ESCompanion.zip

# 4. Sign with Sparkle EdDSA
./bin/sign_update ESCompanion.zip

# 5. Notarize
xcrun notarytool submit ESCompanion.zip \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# 6. Staple (optional, for offline verification)
xcrun stapler staple "Electric Sheep Companion.app"
```

### Hardened Runtime Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Disable library validation for Sparkle -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

## Appcast Format

Host `appcast.xml` on your server:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Electric Sheep Companion Updates</title>
    <link>https://electricsheep.org/appcast.xml</link>
    <item>
      <title>Version 1.0.1</title>
      <sparkle:version>1.0.1</sparkle:version>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
      <pubDate>Wed, 01 Jan 2026 12:00:00 +0000</pubDate>
      <enclosure
        url="https://electricsheep.org/releases/ESCompanion-1.0.1.zip"
        sparkle:edSignature="YOUR_SIGNATURE_HERE"
        length="12345678"
        type="application/octet-stream"/>
      <sparkle:releaseNotesLink>
        https://electricsheep.org/releases/1.0.1.html
      </sparkle:releaseNotesLink>
    </item>
  </channel>
</rss>
```

### Generate Appcast Automatically

```bash
# Sparkle includes a tool to generate appcast from releases
./bin/generate_appcast /path/to/releases/
```

## Update Flow

1. App launches → Sparkle checks `SUFeedURL`
2. If newer version found → Download in background
3. Verify EdDSA signature
4. Verify Apple code signature matches current app
5. Prompt user to install (or auto-install on quit)
6. Replace app bundle, relaunch

## Security Considerations

- **HTTPS required** for appcast and downloads (App Transport Security)
- **EdDSA signature** prevents tampering
- **Apple code signing** ensures updates are from same developer
- **Keep private keys safe** - Not on web server, not in git

## Testing

```bash
# Force update check
defaults write org.electricsheep.companion SUScheduledCheckInterval -int 60

# Clear update state
defaults delete org.electricsheep.companion SULastCheckTime

# Enable verbose logging
defaults write org.electricsheep.companion SUEnableAutomaticChecks -bool YES
```

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [TN3147: Migrating to notarytool](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)
