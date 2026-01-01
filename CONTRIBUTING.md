# Contributing to Electric Sheep macOS

Thank you for your interest in helping restore Electric Sheep to modern macOS!

## Getting Started

1. **Read the [MANIFESTO.md](MANIFESTO.md)** to understand the project vision
2. **Check the [ROADMAP.md](ROADMAP.md)** to see current priorities
3. **Review the [plans/](plans/)** folder for detailed phase documentation

## Development Setup

### Prerequisites

- macOS 10.15 Catalina or later
- Xcode 14+ with command line tools
- Apple Developer account (for code signing)
- Git

### Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/electricsheep.git
cd electricsheep
```

### Project Structure

```
electricsheep/
├── MANIFESTO.md        # Project vision and technical plan
├── ROADMAP.md          # Milestones and progress
├── CONTRIBUTING.md     # This file
├── plans/              # Detailed phase plans
├── client_generic/     # Original Electric Sheep source
│   ├── MacBuild/       # macOS Xcode project
│   └── ...
└── companion/          # New companion app (to be created)
```

## How to Contribute

### 1. Pick a Task

- Check [GitHub Issues](../../issues) for open tasks
- Look at unchecked items in [ROADMAP.md](ROADMAP.md)
- Review phase plans in [plans/](plans/) for specific tasks

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

### 3. Make Your Changes

- Follow existing code style
- Write clear commit messages
- Add comments for complex logic
- Update documentation if needed

### 4. Test Your Changes

- Test on both Intel and Apple Silicon if possible
- Verify screensaver works in System Preferences
- Check menu bar app behavior
- Test sleep/wake cycles

### 5. Submit a Pull Request

- Describe what your PR does
- Reference any related issues
- Include screenshots for UI changes
- Note testing performed

## Code Style

### Swift (Companion App)

- Use SwiftUI for new UI where possible
- Follow Apple's Swift API Design Guidelines
- Use meaningful variable names
- Keep functions focused and small

### Objective-C (Screensaver)

- Match existing Electric Sheep style
- Use modern Objective-C syntax
- Prefer properties over ivars
- Document public interfaces

### C++ (Legacy Code)

- Maintain compatibility with existing code
- Document any modifications thoroughly
- Avoid introducing new dependencies

## Commit Messages

Use conventional commit format:

```
feat: Add sheep download progress indicator
fix: Handle missing cache directory gracefully
docs: Update ROADMAP with Phase 1 progress
refactor: Extract cache manager into separate class
```

## Areas Needing Help

### High Priority

- [ ] Swift developer for companion app
- [ ] macOS screensaver experience
- [ ] Code signing and notarization setup

### Medium Priority

- [ ] UI/UX design for companion app
- [ ] Testing on various macOS versions
- [ ] Documentation improvements

### Low Priority (Future)

- [ ] Apple Silicon GPU optimization
- [ ] 4K/8K video support
- [ ] tvOS port

## Questions?

- Open a [GitHub Issue](../../issues) for bugs or features
- Check existing issues before creating new ones
- Be respectful and constructive

## License

By contributing, you agree that your contributions will be licensed under GPL2, consistent with the original Electric Sheep project.
