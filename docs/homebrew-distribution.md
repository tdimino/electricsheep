# Homebrew Distribution Guide

## Overview

Electric Sheep Companion is distributed via Homebrew Cask for easy installation. Users can install with:

```bash
brew install --cask electric-sheep-companion
```

## Cask Formula

### Example: electric-sheep-companion.rb

```ruby
cask "electric-sheep-companion" do
  version "1.0.0"
  sha256 "abc123..." # SHA256 of the ZIP file

  url "https://github.com/tdimino/electricsheep/releases/download/v#{version}/ElectricSheepCompanion-#{version}.zip",
      verified: "github.com/tdimino/electricsheep/"

  name "Electric Sheep Companion"
  desc "Companion app for Electric Sheep screensaver - downloads sheep, handles voting"
  homepage "https://electricsheep.org/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :catalina"

  app "Electric Sheep Companion.app"

  zap trash: [
    "~/Library/Application Support/ElectricSheep",
    "~/Library/Caches/org.electricsheep.companion",
    "~/Library/Preferences/org.electricsheep.companion.plist",
  ]
end
```

### Key Stanzas

| Stanza | Purpose |
|--------|---------|
| `version` | Current release version |
| `sha256` | Hash of download for verification |
| `url` | Download URL (GitHub releases recommended) |
| `name` | Human-readable app name |
| `desc` | Short description |
| `homepage` | Project website |
| `livecheck` | Auto-detect new versions |
| `auto_updates` | App handles its own updates (Sparkle) |
| `depends_on` | Minimum macOS version |
| `app` | Install .app to /Applications |
| `zap` | Cleanup on `brew uninstall --zap` |

## Sparkle vs Homebrew Updates

**Decision**: Use both, but Sparkle handles updates.

```ruby
# In cask formula
auto_updates true
```

This tells Homebrew the app updates itself, so `brew upgrade` won't touch it.

### User Experience

1. **Install**: `brew install --cask electric-sheep-companion`
2. **Updates**: Sparkle prompts within app
3. **Uninstall**: `brew uninstall electric-sheep-companion`
4. **Clean uninstall**: `brew uninstall --zap electric-sheep-companion`

## Submission Process

### Option 1: Official homebrew-cask (Recommended)

1. Fork `Homebrew/homebrew-cask`
2. Create `Casks/e/electric-sheep-companion.rb`
3. Submit PR
4. Wait for review (usually 1-3 days)

**Requirements**:
- App must be notarized
- Stable release (not beta)
- Download URL must be reliable
- Formula must pass `brew audit --cask electric-sheep-companion`

### Option 2: Self-Hosted Tap

Create your own tap repository:

```bash
# Create tap repo
gh repo create homebrew-electricsheep --public

# Structure
homebrew-electricsheep/
└── Casks/
    └── electric-sheep-companion.rb
```

Users install via:
```bash
brew tap tdimino/electricsheep
brew install --cask electric-sheep-companion
```

## Release Workflow

### 1. Create GitHub Release

```bash
# Tag the release
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# Create release on GitHub with ZIP attached
gh release create v1.0.0 \
    --title "Electric Sheep Companion 1.0.0" \
    --notes "Initial release" \
    ElectricSheepCompanion-1.0.0.zip
```

### 2. Calculate SHA256

```bash
shasum -a 256 ElectricSheepCompanion-1.0.0.zip
# Output: abc123def456... ElectricSheepCompanion-1.0.0.zip
```

### 3. Update Cask Formula

```ruby
version "1.0.0"
sha256 "abc123def456..."
```

### 4. Submit PR (or push to tap)

```bash
cd homebrew-cask
git checkout -b electric-sheep-companion-1.0.0
# Edit Casks/e/electric-sheep-companion.rb
git commit -am "electric-sheep-companion 1.0.0"
git push origin electric-sheep-companion-1.0.0
gh pr create
```

## Testing

```bash
# Audit formula
brew audit --cask electric-sheep-companion

# Test install
brew install --cask electric-sheep-companion

# Test uninstall
brew uninstall --cask electric-sheep-companion

# Test zap (removes preferences/cache)
brew uninstall --zap --cask electric-sheep-companion
```

## Aerial Cask Reference

The Aerial screensaver cask is a good reference:

```ruby
cask "aerial" do
  version "3.6.3"
  sha256 "d0548c8485b57fbab2b04446058df725e8a233c07a2b87b857738971c546ece4"

  url "https://github.com/JohnCoates/Aerial/releases/download/v#{version}/Aerial.saver.zip",
      verified: "github.com/JohnCoates/Aerial/"

  name "Aerial Screensaver"
  desc "Apple TV Aerial screensaver"
  homepage "https://aerialscreensaver.github.io/"

  livecheck do
    url :url
    strategy :github_latest
  end

  conflicts_with cask: "aerial@beta"

  screen_saver "Aerial.saver"

  zap trash: [
    "~/Library/Application Support/Aerial",
    "~/Library/Caches/Aerial",
    ...
  ]
end
```

## Best Practices

1. **Use GitHub Releases** - Reliable, versioned downloads
2. **Include SHA256** - Security verification
3. **Set `auto_updates true`** - If using Sparkle
4. **Comprehensive `zap`** - List all created files/folders
5. **Use `livecheck`** - Enables automatic version detection
6. **Test before submitting** - Run `brew audit` and test install/uninstall

## References

- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Creating a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Aerial Cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/a/aerial.rb)
