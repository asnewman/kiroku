# Kiroku - Project Context

## Project Overview
Kiroku is a simple macOS menubar app for screen recording. It provides an easy way to record your screen and manage past recordings through a clean, minimal interface.

## Architecture

### Core Components
- **kirokuApp.swift**: Main app entry point with NSApplicationDelegate for menubar functionality
- **ContentView.swift**: SwiftUI interface with recording controls and past recordings list
- **ScreenRecordingManager.swift**: Core recording logic using FFmpeg with AVFoundation
- **VideoTrimmerView.swift**: Video trimming interface with AVPlayerView and interactive scrubber
- **kiroku.entitlements**: macOS permissions for screen recording and file access

### Technical Implementation
- **Screen Recording**: Uses FFmpeg with AVFoundation input (`-f avfoundation -i X:none`) 
- **Device Detection**: Dynamically detects screen capture device index by parsing `ffmpeg -list_devices` output
- **FFmpeg Discovery**: Supports multiple installation paths (Homebrew, MacPorts, system install)
- **Permission Handling**: Uses `CGPreflightScreenCaptureAccess()` for proper macOS screen recording permissions
- **File Management**: Saves recordings to `~/Documents/Kiroku Recordings/` with timestamp naming
- **Video Trimming**: AVPlayer-based preview with interactive scrubber and FFmpeg trimming backend
- **GIF Export**: Two-pass FFmpeg conversion with palette generation for optimal quality
- **Clipboard Integration**: Native pasteboard support with proper UTI types
- **QuickTime Compatibility**: Re-encodes trimmed videos with H.264/AAC for universal playback

### Key Features
- Menubar-only interface (no dock icon)
- Dynamic screen device detection for cross-machine compatibility
- FFmpeg installation detection with user guidance
- Past recordings list with open/delete/trim functionality
- Video trimming with interactive scrubber and draggable start/end handles
- GIF export with high-quality palette generation
- Copy to clipboard support for both video and GIF files
- Dropdown menu interface for recording actions
- Proper macOS permission flow
- Cursor capture in screen recordings

## Development Notes

### Dependencies
- FFmpeg (external dependency, auto-detected at runtime)
- AVFoundation and AVKit for video playback and trimming
- macOS 10.15+ for screen recording APIs
- No sandboxing (disabled for external process execution)

### Build Requirements
- Xcode with SwiftUI support
- Screen recording entitlements configured
- No additional frameworks beyond system libraries

### Testing Considerations
- Test on different Mac models (varying camera/display configurations)
- Verify FFmpeg detection across installation methods
- Test permission flows and error states
- Validate recording quality and file output
- Test video trimming across app sessions and different video formats
- Verify QuickTime compatibility of trimmed videos

## Codebase Patterns
- ObservableObject pattern for state management
- Process execution for external FFmpeg calls
- SwiftUI declarative UI with conditional states
- Item-based sheet presentation for robust state management
- KVO observers for AVPlayer state tracking
- Proper error handling and user feedback