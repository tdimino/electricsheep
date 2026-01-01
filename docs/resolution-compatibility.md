# Resolution Compatibility

## Current State

| Tier | Resolution | Format | Source |
|------|------------|--------|--------|
| Free | 800x598 | H.264/AVI | archive.org |
| Gold | 1280x720 | H.264/AVI | CloudFront CDN |
| Infinidream | 1080p+ | Unknown | infinidream.ai |

The current free sheep at 800x598 are unsuitable for modern Retina displays (5K iMac, 4K external monitors). Even Gold's 720p falls short.

## The Problem

- 800x598 sheep on a 5120x2880 iMac = significant upscaling artifacts
- Screensaver uses OpenGL scaling, but quality degrades
- No native 4K content exists in the classic Electric Sheep system

## Options

### 1. Accept Low Resolution (MVP)
- Ship with existing 800x598 sheep
- Document as "classic" aesthetic
- Screensaver upscales with bilinear/bicubic filtering
- Pro: Fastest to implement
- Con: Looks dated on Retina displays

### 2. Gold Sheep Integration
- Support authenticated Gold accounts (1280x720)
- Requires server authentication implementation
- Pro: Better resolution without new infrastructure
- Con: Paywall, still not true HD

### 3. Infinidream Integration
- Scott Draves' successor project at infinidream.ai
- Native 1080p+ content
- Open source: github.com/e-dream-ai
- Has Python API for content access
- Pro: Modern resolution, same creator
- Con: Different system, may require separate integration

### 4. Local Rendering (Future)
- Genomes are resolution-independent (fractal flames)
- Local flam3 rendering can output any resolution
- Could render 4K on user's GPU
- Pro: Any resolution, offline
- Con: Requires GPU compute, significant work

## Infinidream Details

Scott Draves created Infinidream as Electric Sheep's successor:

- Website: infinidream.ai
- GitHub: e-dream-ai
- Features:
  - 1080p animated visuals
  - Python API for developers
  - macOS desktop app
  - Open source

Consider integration as a long-term option for high-resolution content.

## Recommendations

### Phase 1 (MVP)
- Accept 800x598 free sheep
- Add OpenGL filtering for better upscaling
- Document resolution limitation

### Phase 2
- Add Gold account support for 720p
- Investigate Infinidream API compatibility

### Phase 3 (Future)
- Evaluate Infinidream as content source
- Consider local GPU rendering for 4K

## Technical Notes

### Genome Resolution Independence
Fractal flame genomes specify `size` but are mathematically scalable:
```xml
<flame name="sheep_12345" size="1920 1080" ...>
```

The `size` attribute defines render target, not content limitation. Local flam3 renderer can output any resolution from the same genome.

### Display Scaling
Current OpenGL renderer in `RendererGL.cpp` supports texture scaling. Quality improvements possible:
- GL_LINEAR filtering (current)
- Upgrade to mipmapped textures
- Shader-based upscaling (Lanczos, FSR)

## Related
- `plans/phase-5-server-integration.md` - Gold sheep support
- `ROADMAP.md` - 4K/8K as future goal
- Infinidream: infinidream.ai, github.com/e-dream-ai
