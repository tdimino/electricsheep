<p align="center">
<pre>
 _____ _           _        _        ____  _
| ____| | ___  ___| |_ _ __(_) ___  / ___|| |__   ___  ___ _ __
|  _| | |/ _ \/ __| __| '__| |/ __| \___ \| '_ \ / _ \/ _ \ '_ \
| |___| |  __/ (__| |_| |  | | (__   ___) | | | |  __/  __/ |_) |
|_____|_|\___|\___|\__|_|  |_|\___| |____/|_| |_|\___|\___|  __/
                                                           |_|
</pre>
</p>

<h3 align="center">macOS Companion App Project</h3>

<p align="center">
  <a href="https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html"><img src="https://img.shields.io/badge/License-GPL%20v2-blue.svg" alt="License: GPL v2"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-12.0+-brightgreen.svg" alt="macOS"></a>
  <a href="ROADMAP.md"><img src="https://img.shields.io/badge/Status-Phase%202%20Complete-blue.svg" alt="Status"></a>
</p>

---

## About

**Electric Sheep** is a legendary distributed computing screensaver created by [Scott Draves](http://scottdraves.com) in 1999. It harnesses the collective power of thousands of computers to evolve abstract fractal flame animations through genetic algorithms.

> *"Do Androids Dream of Electric Sheep?"* - Philip K. Dick

**This fork** aims to restore full Electric Sheep functionality on modern macOS (Catalina 10.15+) by creating a companion app architecture that works around Apple's screensaver sandbox restrictions.

## The Problem

Since macOS Catalina (2019), Apple sandboxed third-party screensavers, breaking Electric Sheep's core features:
- No sheep downloading
- No voting
- No distributed rendering
- No auto-updates

## The Solution

A **Companion App** that runs outside the sandbox:

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Electric Sheep         │     │  Electric Sheep         │
│  Companion App          │────▶│  Screensaver            │
│  (Full network access)  │     │  (Display only)         │
└─────────────────────────┘     └─────────────────────────┘
         │
         ▼
  ~/Library/Application Support/ElectricSheep/
```

## Current Status

**Phase 2: Companion App Complete** - The menu bar companion app is working and downloading sheep!

- ✅ Menu bar app with sheep count badge
- ✅ Fetches sheep list from sheepserver.net
- ✅ Downloads sheep to local cache
- ✅ Configurable cache size (1-20 GB)
- 🔲 Screensaver integration (Phase 3)

See [ROADMAP.md](ROADMAP.md) for full progress.

## Quick Links

- [MANIFESTO.md](MANIFESTO.md) - Full project vision and technical plan
- [ROADMAP.md](ROADMAP.md) - Milestones and progress tracking
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to help
- [plans/](plans/) - Detailed implementation phases

## Installation

### Companion App (Downloads Sheep)

Requires macOS 12.0+ and Xcode.

```bash
# Clone and build
git clone https://github.com/tdimino/electricsheep.git
cd electricsheep/Companion/ElectricSheepCompanion

# Install XcodeGen if needed
brew install xcodegen

# Build and run
xcodegen generate
xcodebuild -scheme ElectricSheepCompanion -configuration Release build
open ~/Library/Developer/Xcode/DerivedData/ElectricSheepCompanion-*/Build/Products/Release/ElectricSheepCompanion.app
```

The app appears in your menu bar and starts downloading sheep automatically.

### Screensaver

*Coming in Phase 3* - For now, you can play downloaded sheep with:

```bash
open ~/Library/Application\ Support/ElectricSheep/sheep/free/*.avi
```

## Contributing

We need help! See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get involved.

**Priority areas:**
- Swift development for companion app
- macOS screensaver expertise
- Testing on various macOS versions

## Related Projects

- [Original Electric Sheep](https://github.com/scottdraves/electricsheep) by Scott Draves
- [flam3](https://github.com/scottdraves/flam3) - Fractal flame renderer
- [Aerial Screensaver](https://github.com/JohnCoates/Aerial) - Reference implementation for companion app pattern
- [Infinidream](https://infinidream.ai) - Scott Draves' new project

## Credits

- **Scott Draves** - Creator of Electric Sheep and the fractal flame algorithm
- **Aerial Screensaver Team** - For pioneering the companion app solution
- **Electric Sheep Community** - 25+ years of collaborative art

## License

GPL v2 - See [client_generic/COPYING](client_generic/COPYING)

---

<p align="center">
  <i>"When computers sleep, they dream of Electric Sheep."</i>
</p>
