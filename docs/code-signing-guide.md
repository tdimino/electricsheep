# Code Signing & Notarization Guide

## Overview

Electric Sheep Companion is distributed outside the App Store, requiring:
1. **Developer ID signing** - Proves app is from identified developer
2. **Notarization** - Apple scans for malware, issues ticket
3. **Hardened Runtime** - Security restrictions Apple requires

## Prerequisites

- Apple Developer Program membership ($99/year)
- Xcode 14+ with command line tools
- Developer ID Application certificate

## Certificates

### Required Certificate

**Developer ID Application** - For signing apps distributed outside App Store

```bash
# List available signing identities
security find-identity -v -p codesigning

# Should show:
# "Developer ID Application: Your Name (TEAMID)"
```

### Creating Certificate (if needed)

1. Go to [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
2. Click "+" → Developer ID Application
3. Follow CSR generation steps
4. Download and double-click to install

## Signing the App

### Xcode Automatic Signing

In Xcode project settings:
- Signing & Capabilities → Select team
- Signing Certificate: "Developer ID Application"

### Manual Signing

```bash
# Sign the app bundle
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" \
    --options runtime \
    "Electric Sheep Companion.app"

# Verify signature
codesign --verify --deep --strict --verbose=2 "Electric Sheep Companion.app"

# Check Gatekeeper acceptance
spctl -a -t exec -vv "Electric Sheep Companion.app"
```

## Entitlements

Create `Entitlements.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access for sheep downloads -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Disable library validation (for Sparkle framework) -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>

    <!-- Allow unsigned executable memory (if using JIT) -->
    <!-- <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/> -->
</dict>
</plist>
```

### Entitlements for Electric Sheep

| Entitlement | Required | Reason |
|-------------|----------|--------|
| `network.client` | Yes | Download sheep, submit votes |
| `disable-library-validation` | Yes | Load Sparkle framework |
| `allow-jit` | No | Not using JIT |
| `files.user-selected.read-write` | No | Using App Support dir |

## Notarization

### Using notarytool (Xcode 14+)

```bash
# Store credentials in keychain (one time)
xcrun notarytool store-credentials "AC_PASSWORD" \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"

# Create ZIP for upload
ditto -c -k --keepParent "Electric Sheep Companion.app" ESCompanion.zip

# Submit for notarization
xcrun notarytool submit ESCompanion.zip \
    --keychain-profile "AC_PASSWORD" \
    --wait

# Check status
xcrun notarytool log <submission-id> --keychain-profile "AC_PASSWORD"
```

### Stapling

After notarization succeeds, staple the ticket to the app:

```bash
xcrun stapler staple "Electric Sheep Companion.app"
```

This embeds the notarization ticket so the app works offline.

### Common Notarization Errors

| Error | Fix |
|-------|-----|
| "not signed with hardened runtime" | Add `--options runtime` to codesign |
| "library not signed" | Sign embedded frameworks |
| "uses deprecated API" | Usually just a warning, still passes |
| "missing entitlement" | Check entitlements file |

## DMG Distribution

### Creating Signed DMG

```bash
# Create DMG
hdiutil create -volname "Electric Sheep Companion" \
    -srcfolder "Electric Sheep Companion.app" \
    -ov -format UDZO \
    ESCompanion.dmg

# Sign DMG
codesign --sign "Developer ID Application: Your Name (TEAMID)" \
    ESCompanion.dmg

# Notarize DMG
xcrun notarytool submit ESCompanion.dmg \
    --keychain-profile "AC_PASSWORD" \
    --wait

# Staple DMG
xcrun stapler staple ESCompanion.dmg
```

## Verification Checklist

```bash
# 1. Code signature valid
codesign --verify --deep --strict "Electric Sheep Companion.app"

# 2. Gatekeeper accepts
spctl -a -t exec -vv "Electric Sheep Companion.app"

# 3. Notarization ticket attached
stapler validate "Electric Sheep Companion.app"

# 4. Check entitlements
codesign -d --entitlements - "Electric Sheep Companion.app"
```

## Automation Script

```bash
#!/bin/bash
set -e

APP_NAME="Electric Sheep Companion"
BUNDLE_ID="org.electricsheep.companion"
TEAM_ID="YOUR_TEAM_ID"

# Build
xcodebuild -scheme "$APP_NAME" -configuration Release build

# Sign
codesign --force --deep --sign "Developer ID Application: Your Name ($TEAM_ID)" \
    --options runtime \
    --entitlements Entitlements.plist \
    "build/Release/$APP_NAME.app"

# Create ZIP
ditto -c -k --keepParent "build/Release/$APP_NAME.app" "$APP_NAME.zip"

# Notarize
xcrun notarytool submit "$APP_NAME.zip" \
    --keychain-profile "AC_PASSWORD" \
    --wait

# Staple
xcrun stapler staple "build/Release/$APP_NAME.app"

echo "Done! App is signed and notarized."
```

## References

- [Apple: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [TN3147: Migrating to notarytool](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
