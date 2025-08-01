# Kiroku - Project Context

## Project Overview
Kiroku is a macOS menubar app for continuous screen recording with a rolling buffer system. It automatically records the screen in 10-second chunks, maintaining a 2-minute buffer (to prevent file deletion issues), and allows users to export the last 1 minute of activity on demand.

## Architecture

### Core Components
- **kirokuApp.swift**: Main app entry point with NSApplicationDelegate for menubar functionality
- **ContentView.swift**: SwiftUI interface with always-recording status and past recordings list
- **ScreenRecordingManager.swift**: Core continuous recording logic using native screencapture with rolling buffer management
- **VideoTrimmerView.swift**: Video trimming and cropping interface with AVPlayerView, interactive scrubber, and crop overlay
- **kiroku.entitlements**: macOS permissions for screen recording and file access (camera/microphone removed)
- **Info.plist**: Minimal configuration without camera/microphone privacy descriptions

### Technical Implementation
- **Continuous Recording**: Uses `screencapture -v -V 10` for 10-second chunk recording with automatic termination
- **Rolling Buffer**: Maintains 2-minute buffer by automatically cleaning chunks older than 120 seconds
- **Chunk Management**: Sequential chunk processing with natural process termination using screencapture's built-in timeout
- **Export Functionality**: FFmpeg concat demuxer for seamless merging of buffer chunks into final recordings
- **FFmpeg Discovery**: Supports multiple installation paths (Homebrew, MacPorts, system install) for video processing
- **Permission Handling**: Uses `CGPreflightScreenCaptureAccess()` for screen recording permissions only
- **File Management**: Buffer chunks stored in `~/Documents/Kiroku Buffer/`, final recordings in `~/Documents/Kiroku Recordings/`
- **Video Trimming**: AVPlayer-based preview with interactive scrubber and FFmpeg trimming backend
- **Video Cropping**: Interactive crop selection overlay in trim editor with coordinate scaling from preview to actual video dimensions
- **GIF Export**: Two-pass FFmpeg conversion with palette generation for optimal quality
- **Clipboard Integration**: Native pasteboard support with proper UTI types
- **QuickTime Compatibility**: Re-encodes trimmed videos with H.264/AAC for universal playback

### Key Features
- Menubar-only interface (no dock icon)
- Always-recording mode with visual indicator and chunk count display
- "Save Last 1 Minute" export functionality with progress indication
- Automatic buffer clearing on app startup for fresh sessions
- Rolling buffer management with automatic cleanup of old chunks
- Past recordings list with open/delete/trim functionality
- Video trimming with interactive scrubber and draggable start/end handles
- Video cropping in trim editor with interactive crop selection overlay
- Real-time crop dimension display showing both overlay and actual video coordinates
- Reset crop functionality for easy re-selection
- GIF export with high-quality palette generation
- Copy to clipboard support for both video and GIF files
- Proper macOS permission flow for screen recording
- Cursor capture in screen recordings

## Development Notes

### Dependencies
- FFmpeg (external dependency, auto-detected at runtime for chunk merging, GIF export, and video cropping)
- AVFoundation and AVKit for video playback and trimming
- macOS 10.15+ for screen recording APIs
- No sandboxing (disabled for external process execution)

### Build Requirements
- Xcode with SwiftUI support
- Screen recording entitlements configured (camera/microphone removed)
- Minimal Info.plist without camera/microphone privacy descriptions
- No additional frameworks beyond system libraries

### Testing Considerations
- Test continuous recording stability over extended periods
- Verify chunk creation timing and file size consistency
- Test buffer management and automatic cleanup functionality
- Verify export functionality with various numbers of chunks
- Test permission flows for screen recording access
- Validate chunk recording with screencapture -V flag
- Test video trimming across app sessions and different video formats
- Test video cropping with various crop sizes and positions
- Verify crop coordinate scaling accuracy from overlay to actual video dimensions
- Test crop reset functionality and re-selection
- Verify QuickTime compatibility of trimmed and cropped videos
- Test app startup buffer clearing
- Validate FFmpeg chunk merging accuracy and synchronization

## Codebase Patterns
- ObservableObject pattern for state management
- Process execution for native screencapture and FFmpeg operations
- SwiftUI declarative UI with always-recording state indicators
- Item-based sheet presentation for robust state management
- KVO observers for AVPlayer state tracking
- Sequential chunk processing with natural process termination
- Rolling buffer management with automatic cleanup
- Interactive SwiftUI overlays for crop selection with drag gestures
- Coordinate scaling and validation for video processing
- Proper error handling and user feedback