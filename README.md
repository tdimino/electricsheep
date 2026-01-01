<div align="center">
<pre>
 _____ _           _        _        ____  _
| ____| | ___  ___| |_ _ __(_) ___  / ___|| |__   ___  ___ _ __
|  _| | |/ _ \/ __| __| '__| |/ __| \___ \| '_ \ / _ \/ _ \ '_ \
| |___| |  __/ (__| |_| |  | | (__   ___) | | | |  __/  __/ |_) |
|_____|_|\___|\___|\__|_|  |_|\___| |____/|_| |_|\___|\___|  __/
                                                           |_|
                  macOS Companion App Project
</pre>
</div>

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![macOS](https://img.shields.io/badge/macOS-10.15+-brightgreen.svg)](https://www.apple.com/macos/)
[![Status](https://img.shields.io/badge/Status-Planning-yellow.svg)](ROADMAP.md)

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

**Phase 0: Planning Complete** - See [ROADMAP.md](ROADMAP.md) for details.

## Quick Links

- [MANIFESTO.md](MANIFESTO.md) - Full project vision and technical plan
- [ROADMAP.md](ROADMAP.md) - Milestones and progress tracking
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to help
- [plans/](plans/) - Detailed implementation phases

## Installation

*Coming soon!* For now, Electric Sheep only works as a regular application on modern macOS.

**Current workaround:**
1. Download Electric Sheep from [electricsheep.org](https://electricsheep.org)
2. Run it as a regular app (not as a screensaver)
3. Leave it running to download sheep

## Building from Source

```bash
# Clone this fork
git clone https://github.com/YOUR_USERNAME/electricsheep.git
cd electricsheep

# Open the Xcode project
open client_generic/MacBuild/ElectricSheep.xcodeproj
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
