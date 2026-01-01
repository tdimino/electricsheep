# Rendering Pipeline

## Overview

Electric Sheep decodes MPEG2 videos via FFmpeg and renders them via OpenGL/DirectX.

## Pipeline Stages

```
FFmpeg Decode → CVideoFrame → Queue → Texture Upload → OpenGL Quad → Display
```

## Video Decoding (ContentDecoder/)

### CContentDecoder
**File:** `client_generic/ContentDecoder/ContentDecoder.cpp`

FFmpeg wrapper managing the decode pipeline.

**Key Structures:**
```cpp
struct sOpenVideoInfo {
    AVFrame *m_pFrame;                    // Raw decoded frame
    AVFormatContext *m_pFormatContext;    // File metadata
    AVCodecContext *m_pVideoCodecContext; // Codec state
    const AVCodec *m_pVideoCodec;         // Codec impl
    SwsContext *m_pScaler;                // Pixel format converter
    uint32 m_totalFrameCount;             // Total frames
};
```

**Decode Flow (ReadOneFrame):**
1. `avcodec_receive_frame()` - Get decoded frame
2. If EAGAIN: `av_read_frame()` + `avcodec_send_packet()`
3. `sws_scale()` - Convert to RGB24
4. Create `CVideoFrame` wrapper with metadata

### CVideoFrame
**File:** `client_generic/ContentDecoder/Frame.h`

Decoded frame container:
```cpp
class CVideoFrame {
    uint32 m_Width, m_Height;
    fp8 m_Pts;                          // Presentation timestamp
    sMetaData m_MetaData;               // Sheep info
    Base::spCAlignedBuffer m_spBuffer;  // Aligned pixel data
};

struct sMetaData {
    std::string m_FileName;
    uint32 m_SheepID, m_SheepGeneration;
    bool m_IsEdge;
    spCVideoFrame m_SecondFrame;        // For transitions
    fp4 m_TransitionProgress;           // 0-100%
};
```

## Threading

Two worker threads:
1. **Decoder Thread** (`ReadPackets`) - Reads frames, manages transitions
2. **Next Sheep Calculator** - Determines playlist order

Threadsafe queue connects decoder to display:
```cpp
Base::CBlockingQueue<CVideoFrame*> m_FrameQueue;
```

## Display Rendering (DisplayOutput/)

### CRenderer
**File:** `client_generic/DisplayOutput/Renderer/Renderer.h`

Abstract rendering API with OpenGL and DirectX implementations.

**Key Methods:**
```cpp
BeginFrame()                    // Frame setup
EndFrame(drawn)                 // Cleanup
NewTextureFlat()                // Create texture
SetTexture(texture, unit)       // Bind texture
SetShader(shader)               // Set shader
SetBlend(mode)                  // Alpha blend
Apply()                         // Commit state
DrawQuad(rect, color)           // Render textured quad
```

### Frame Display (CFrameDisplay)
**File:** `client_generic/Client/FrameDisplay.h`

Renders video frames as textured quads.

**Update Loop:**
```cpp
bool Update(decoder, decodeFps, displayFps, metadata) {
    // 1. Check if time for next decoded frame
    if (UpdateInterframeDelta(decodeFps)) {
        // 2. Grab frame from decoder queue
        GrabFrame(decoder, texture, secondTexture, metadata);

        // 3. Upload pixels to GPU
        image->SetStorageBuffer(frame->StorageBuffer());
        texture->Upload(image);
    }

    // 4. Calculate interpolation alpha
    alpha = Clamped(lastAlpha + delta / fadeCount);

    // 5. Render main quad
    renderer->SetBlend("alphablend");
    renderer->SetTexture(texture, 0);
    renderer->DrawQuad(screenRect, rgba(1,1,1,alpha));

    // 6. If transitioning, blend second sheep
    if (secondTexture) {
        renderer->DrawQuad(screenRect, rgba(1,1,1,alpha*progress));
    }
}
```

## Player Coordination (CPlayer)

**File:** `client_generic/Client/Player.cpp`

Manages multiple displays and decoders.

**Display Unit:**
```cpp
struct DisplayUnit {
    spCDisplayOutput spDisplay;      // Window/surface
    spCRenderer spRenderer;          // Rendering API
    spCContentDecoder spDecoder;     // Video decoder
    spCFrameDisplay spFrameDisplay;  // Frame renderer
};
```

**Multi-Display Modes:**
- `kMDSharedMode` - One decoder, all displays same sheep
- `kMDIndividualMode` - Each display has own decoder
- `kMDSingleScreen` - Single monitor

## Frame Rates

- Decode FPS: `settings.player.player_fps` (default: 23)
- Display FPS: `settings.player.display_fps` (default: 60)
- Interpolation smooths decode frames to display rate

## Transitions

Last 60 frames of current sheep cross-fade to next sheep:
1. Decoder reads both current and next sheep
2. `m_SecondFrame` holds next sheep's frame
3. `m_TransitionProgress` animates 0% → 100%
4. Alpha blending combines both textures
