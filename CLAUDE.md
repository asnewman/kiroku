# Kiroku - Project Context

## Project Overview
Kiroku is a macOS menubar app for continuous screen recording with a rolling buffer system. It automatically records the screen in 10-second chunks, maintaining a 2-minute buffer (to prevent file deletion issues), and allows users to export the last 1 minute of activity on demand.

## Architecture

**Pattern**: MVVM-C (Model-View-ViewModel-Coordinator) with Dependency Injection

### Directory Structure
```
kiroku/
├── App/ (DI Container, App Coordinator, Main App)
├── Core/ 
│   ├── Models/ (Recording, VideoChunk, Configurations)
│   ├── Services/ (Screen Recording, Video Processing, File Management)
│   ├── Repositories/ (Recording, Buffer, Settings)
│   └── Utilities/ (Process Execution, FFmpeg, Screen Capture)
├── Features/
│   ├── Recording/ (Views, ViewModels, Coordinators)
│   └── VideoEditing/ (Views, ViewModels, Coordinators)
```

### Core Components
- **App/kirokuApp.swift**: Main app entry point with NSApplicationDelegate for menubar functionality
- **App/AppCoordinator.swift**: Central navigation coordinator managing app flow
- **App/DIContainer.swift**: Dependency injection container providing all services and ViewModels
- **Features/Recording/Views/ContentView.swift**: SwiftUI interface with always-recording status and past recordings list
- **Features/Recording/ViewModels/ContentViewModel.swift**: Business logic for main interface
- **Features/VideoEditing/Views/VideoTrimmerView.swift**: Video trimming and cropping interface
- **Core/Services/**: Protocol-oriented service layer (ScreenRecording, VideoProcessing, FileManagement, etc.)
- **Core/Repositories/**: Data access layer (Recording, Buffer, Settings repositories)
- **Core/Models/**: Domain models (Recording, VideoChunk, TrimConfiguration, etc.)
- **kiroku.entitlements**: macOS permissions for screen recording and file access
- **CODING_STYLE.md**: Comprehensive coding standards and architectural guidelines

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
- **Logging System**: Comprehensive os.log integration with categories (Recording, Buffer, Export, FileSystem, UI, Permissions, Process, Video)

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

### Recent Updates
- Fixed video trimmer presentation to use actual VideoTrimmerView instead of placeholder
- Added proper sheet dismissal handling for video trimmer (clearing selectedRecording)
- Created public interface method in ContentViewModel to access video editing coordinator
- Improved separation of concerns between View and ViewModel layers
- Fixed trimmed videos not appearing in recordings list by automatically adding them to repository
- Added proper file size calculation and logging for trimmed recordings

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

## Architectural Principles
- **MVVM-C Pattern**: Strict separation of concerns with coordinators for navigation
- **Protocol-Oriented Design**: All services use protocols for testability and flexibility
- **Dependency Injection**: Complete DI container managing all dependencies
- **Reactive State Management**: Combine publishers for reactive UI updates
- **Async/Await**: Modern Swift concurrency throughout the codebase
- **Single Responsibility**: Each component has one clear purpose
- **Testability First**: Every component can be unit tested in isolation

## Codebase Patterns
- **@MainActor ViewModels**: Main thread isolation for UI state management
- **Repository Pattern**: Data access abstraction layer
- **Service Layer**: Business logic separated from UI components
- **Coordinator Pattern**: Navigation logic separated from views
- **Process Execution Abstraction**: External dependencies wrapped in protocols
- **Domain Models**: Strong typing with domain-specific models
- **Error Handling**: Comprehensive error types and propagation
- **SwiftUI Best Practices**: Declarative UI with proper state management
- **Protocol Boundaries**: Clear interfaces between layers
- **Async Operation Management**: Proper task lifecycle and cancellation