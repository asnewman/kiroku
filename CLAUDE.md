# Kiroku - Project Context

## Project Overview
Kiroku is a simple macOS menubar app for screen recording. It provides an easy way to record your screen and manage past recordings through a clean, minimal interface.

## Architecture

### Core Components
- **kirokuApp.swift**: Main app entry point with NSApplicationDelegate for menubar functionality
- **ContentView.swift**: SwiftUI interface with recording controls, configure dropdown, and past recordings list
- **ScreenRecordingManager.swift**: Core recording logic using native screencapture
- **WebcamPreviewWindow.swift**: Floating webcam preview window with circular mask
- **VideoTrimmerView.swift**: Video trimming and cropping interface with AVPlayerView, interactive scrubber, and crop overlay
- **kiroku.entitlements**: macOS permissions for screen recording, camera, microphone, and file access
- **Info.plist**: Privacy descriptions for camera and microphone usage

### Technical Implementation
- **Screen Recording**: Uses native macOS `screencapture -v` command for reliable recording
- **Audio Recording**: Uses `screencapture -g` flag for microphone input with configurable offset
- **Webcam Preview**: Floating window with circular mask positioned in configurable corners (captured as part of screen)
- **FFmpeg Discovery**: Supports multiple installation paths (Homebrew, MacPorts, system install) for video processing
- **Permission Handling**: Uses `CGPreflightScreenCaptureAccess()` for screen recording and `AVCaptureDevice.requestAccess()` for microphone/camera permissions
- **File Management**: Saves recordings to `~/Documents/Kiroku Recordings/` with timestamp naming
- **Video Trimming**: AVPlayer-based preview with interactive scrubber and FFmpeg trimming backend
- **Video Cropping**: Interactive crop selection overlay in trim editor with coordinate scaling from preview to actual video dimensions
- **GIF Export**: Two-pass FFmpeg conversion with palette generation for optimal quality
- **Clipboard Integration**: Native pasteboard support with proper UTI types
- **QuickTime Compatibility**: Re-encodes trimmed videos with H.264/AAC for universal playback

### Key Features
- Menubar-only interface (no dock icon)
- Configure dropdown with webcam overlay and audio recording toggles
- Optional webcam overlay shown as floating preview window during recording
- Configurable webcam position (all four corners: top-left, top-right, bottom-left, bottom-right)
- Optional microphone audio recording with configurable offset for sync
- Native screencapture backend for maximum compatibility
- Past recordings list with open/delete/trim functionality
- Video trimming with interactive scrubber and draggable start/end handles
- Video cropping in trim editor with interactive crop selection overlay
- Real-time crop dimension display showing both overlay and actual video coordinates
- Reset crop functionality for easy re-selection
- GIF export with high-quality palette generation
- Copy to clipboard support for both video and GIF files
- Dropdown menu interface for recording actions
- Proper macOS permission flow for screen recording, camera, and microphone
- Cursor capture in screen recordings

## Development Notes

### Dependencies
- FFmpeg (external dependency, auto-detected at runtime for GIF export and video cropping)
- AVFoundation and AVKit for video playback, trimming, and webcam preview
- macOS 10.15+ for screen recording APIs
- No sandboxing (disabled for external process execution)

### Build Requirements
- Xcode with SwiftUI support
- Screen recording, camera, and microphone entitlements configured
- Custom Info.plist with NSCameraUsageDescription and NSMicrophoneUsageDescription
- No additional frameworks beyond system libraries

### Testing Considerations
- Test on different Mac models (varying camera/display configurations)
- Verify FFmpeg detection across installation methods
- Test permission flows for screen recording, camera, and microphone access
- Validate recording quality and file output with and without webcam preview
- Test audio/video sync with different offset values
- Test video trimming across app sessions and different video formats
- Test video cropping with various crop sizes and positions
- Verify crop coordinate scaling accuracy from overlay to actual video dimensions
- Test crop reset functionality and re-selection
- Verify QuickTime compatibility of trimmed and cropped videos
- Test webcam preview window positioning in all four corners
- Validate webcam position changes during active preview
- Validate microphone audio capture quality and sync

## Codebase Patterns
- ObservableObject pattern for state management
- Process execution for native screencapture and FFmpeg operations
- SwiftUI declarative UI with conditional states and configure dropdown
- Item-based sheet presentation for robust state management
- KVO observers for AVPlayer state tracking
- Floating NSWindow for webcam preview with circular mask
- Interactive SwiftUI overlays for crop selection with drag gestures
- Coordinate scaling and validation for video processing
- Proper error handling and user feedback