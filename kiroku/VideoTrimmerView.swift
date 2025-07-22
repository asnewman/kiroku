//
//  VideoTrimmerView.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoTrimmerView: View {
    let videoURL: URL
    let onTrimComplete: (URL) -> Void
    let onCancel: () -> Void
    
    @StateObject private var playerObserver: PlayerObserver
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isPlaying = false
    @State private var isTrimming = false
    @State private var trimError: String?
    @State private var cropEnabled = false
    @State private var cropRect: CGRect = .zero
    @State private var videoSize: CGSize = .zero
    @State private var actualVideoSize: CGSize = .zero
    
    init(videoURL: URL, onTrimComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.videoURL = videoURL
        self.onTrimComplete = onTrimComplete
        self.onCancel = onCancel
        self._playerObserver = StateObject(wrappedValue: PlayerObserver())
    }
    
    private var player: AVPlayer {
        playerObserver.player
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Text("Trim Video")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(cropEnabled ? "Crop ON" : "Crop OFF") {
                        cropEnabled.toggle()
                        if !cropEnabled {
                            cropRect = .zero
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(cropEnabled ? .green : .secondary)
                    
                    if cropEnabled && cropRect != .zero {
                        Button("Reset") {
                            cropRect = .zero
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.secondary)
                    }
                }
                
                Button("Save Trim") {
                    trimVideo()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTrimming || endTime <= startTime)
            }
            .padding()
            
            // Video Player
            Group {
                if duration > 0 {
                    ZStack {
                        VideoPlayer(player: player)
                            .frame(height: 300)
                            .cornerRadius(8)
                        
                        if cropEnabled {
                            CropOverlay(
                                cropRect: $cropRect,
                                videoSize: $videoSize,
                                frameSize: CGSize(width: 400, height: 300),
                                actualVideoSize: actualVideoSize
                            )
                            .frame(height: 300)
                            .cornerRadius(8)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading video...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(videoURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Duration: \(duration)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .onAppear {
                // Add a small delay to ensure AVFoundation is fully initialized
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    setupPlayer()
                }
            }
            .onDisappear {
                playerObserver.cleanup()
            }
            
            // Playback Controls
            HStack(spacing: 16) {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button("⏮") {
                    seekTo(time: startTime)
                }
                .buttonStyle(.bordered)
                
                Button("⏭") {
                    seekTo(time: endTime)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Time Display
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Duration: \(formatTime(endTime - startTime))")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Scrubber and Trim Controls
            VStack(spacing: 12) {
                // Main scrubber
                HStack {
                    Text("0:00")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 4)
                        
                        // Trim selection
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: max(0, (endTime - startTime) / duration * 280), height: 8)
                            .offset(x: startTime / duration * 280)
                        
                        // Current time indicator
                        Circle()
                            .fill(Color.white)
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .offset(x: currentTime / duration * 280 - 6)
                        
                        // Start time handle
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .offset(x: startTime / duration * 280 - 8)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newStartTime = max(0, min(duration, (value.location.x / 280) * duration))
                                        if newStartTime < endTime {
                                            startTime = newStartTime
                                        }
                                    }
                            )
                        
                        // End time handle
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .offset(x: endTime / duration * 280 - 8)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newEndTime = max(0, min(duration, (value.location.x / 280) * duration))
                                        if newEndTime > startTime {
                                            endTime = newEndTime
                                        }
                                    }
                            )
                    }
                    .frame(width: 280, height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let newTime = (location.x / 280) * duration
                        seekTo(time: newTime)
                    }
                    
                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Trim time inputs
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(formatTime(startTime))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                            
                            Button("Set") {
                                startTime = currentTime
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("End Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Button("Set") {
                                endTime = currentTime
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            
                            Text(formatTime(endTime))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if let error = trimError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            if isTrimming {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Re-encoding video for QuickTime compatibility...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 500, height: 600)
    }
    
    private func setupPlayer() {
        playerObserver.setupPlayer(url: videoURL) { currentTime, duration, isPlaying in
            self.currentTime = currentTime
            if let duration = duration {
                self.duration = duration
                self.endTime = duration
            }
            self.isPlaying = isPlaying
        }
        
        // Get actual video dimensions
        Task {
            do {
                let asset = AVURLAsset(url: videoURL)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    await MainActor.run {
                        self.actualVideoSize = naturalSize
                    }
                }
            } catch {
                print("Failed to get video dimensions: \(error)")
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func seekTo(time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func trimVideo() {
        guard !isTrimming else { return }
        
        isTrimming = true
        trimError = nil
        
        Task {
            do {
                let trimmedURL = try await VideoTrimmer.trimVideo(
                    inputURL: videoURL,
                    startTime: startTime,
                    endTime: endTime,
                    cropRect: cropEnabled ? cropRect : nil,
                    overlayFrameSize: CGSize(width: 400, height: 300),
                    actualVideoSize: actualVideoSize
                )
                
                await MainActor.run {
                    isTrimming = false
                    onTrimComplete(trimmedURL)
                }
            } catch {
                await MainActor.run {
                    isTrimming = false
                    trimError = "Failed to trim video: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Helper class for video trimming operations
class VideoTrimmer {
    static func trimVideo(inputURL: URL, startTime: Double, endTime: Double, cropRect: CGRect? = nil, overlayFrameSize: CGSize = .zero, actualVideoSize: CGSize = .zero) async throws -> URL {
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let baseFilename = cropRect != nil ? "Trimmed+Cropped" : "Trimmed"
        let trimmedFilename = "\(baseFilename) - \(formatter.string(from: Date())).mov"
        let outputURL = recordingsDir.appendingPathComponent(trimmedFilename)
        
        // Use FFmpeg for trimming and cropping
        return try await trimWithFFmpeg(
            inputURL: inputURL,
            outputURL: outputURL,
            startTime: startTime,
            duration: endTime - startTime,
            cropRect: cropRect,
            overlayFrameSize: overlayFrameSize,
            actualVideoSize: actualVideoSize
        )
    }
    
    private static func trimWithFFmpeg(inputURL: URL, outputURL: URL, startTime: Double, duration: Double, cropRect: CGRect? = nil, overlayFrameSize: CGSize = .zero, actualVideoSize: CGSize = .zero) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // Find FFmpeg path (reuse logic from ScreenRecordingManager)
            guard let ffmpegPath = findFFmpegPath() else {
                continuation.resume(throwing: TrimError.ffmpegNotFound)
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            var arguments = [
                "-i", inputURL.path,
                "-ss", String(format: "%.2f", startTime),
                "-t", String(format: "%.2f", duration)
            ]
            
            // Add crop filter if cropping is enabled
            if let cropRect = cropRect, cropRect != .zero, overlayFrameSize != .zero, actualVideoSize != .zero {
                // Scale crop coordinates from overlay frame to actual video dimensions
                let scaleX = actualVideoSize.width / overlayFrameSize.width
                let scaleY = actualVideoSize.height / overlayFrameSize.height
                
                let scaledX = Int(cropRect.origin.x * scaleX)
                let scaledY = Int(cropRect.origin.y * scaleY)
                let scaledWidth = Int(cropRect.width * scaleX)
                let scaledHeight = Int(cropRect.height * scaleY)
                
                // Ensure crop dimensions are within video bounds and even numbers (required by H.264)
                let finalX = max(0, min(scaledX, Int(actualVideoSize.width) - 2))
                let finalY = max(0, min(scaledY, Int(actualVideoSize.height) - 2))
                let finalWidth = max(2, min(scaledWidth, Int(actualVideoSize.width) - finalX))
                let finalHeight = max(2, min(scaledHeight, Int(actualVideoSize.height) - finalY))
                
                // Make width and height even (required by H.264 encoder)
                let evenWidth = finalWidth - (finalWidth % 2)
                let evenHeight = finalHeight - (finalHeight % 2)
                
                let cropFilter = "crop=\(evenWidth):\(evenHeight):\(finalX):\(finalY)"
                arguments.append(contentsOf: ["-vf", cropFilter])
            }
            
            arguments.append(contentsOf: [
                "-c:v", "libx264", // Re-encode video for compatibility
                "-c:a", "aac", // Re-encode audio for compatibility
                "-preset", "medium", // Balance between speed and quality
                "-crf", "18", // High quality constant rate factor
                "-movflags", "+faststart", // Optimize for streaming/QuickTime
                "-avoid_negative_ts", "make_zero",
                "-y", // Overwrite output file
                outputURL.path
            ])
            
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = FileHandle.nullDevice
            
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: TrimError.ffmpegFailed(errorOutput))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: TrimError.processStartFailed(error))
            }
        }
    }
    
    private static func findFFmpegPath() -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg", 
            "/usr/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try using 'which' command as fallback
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            print("Failed to locate ffmpeg with 'which' command: \(error)")
        }
        
        return nil
    }
}

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    @Binding var videoSize: CGSize
    let frameSize: CGSize
    let actualVideoSize: CGSize
    
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Darker semi-transparent overlay
                Color.black.opacity(0.6)
                
                // Crop rectangle with enhanced visibility
                if cropRect != .zero {
                    ZStack {
                        // Clear area for the crop
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .blendMode(.destinationOut)
                        
                        // Bright border with shadow for better visibility
                        Rectangle()
                            .stroke(Color.cyan, lineWidth: 3)
                            .background(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1)
                                    .offset(x: 1, y: 1)
                            )
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                        
                        // Corner handles for better visual feedback
                        ForEach(0..<4) { index in
                            let corners = [
                                CGPoint(x: cropRect.minX, y: cropRect.minY), // Top-left
                                CGPoint(x: cropRect.maxX, y: cropRect.minY), // Top-right
                                CGPoint(x: cropRect.minX, y: cropRect.maxY), // Bottom-left
                                CGPoint(x: cropRect.maxX, y: cropRect.maxY)  // Bottom-right
                            ]
                            
                            Circle()
                                .fill(Color.cyan)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 10, height: 10)
                                .position(corners[index])
                        }
                    }
                }
                
                // Crop info with enhanced visibility
                if cropRect != .zero {
                    VStack {
                        VStack(spacing: 3) {
                            Text("Overlay: \(Int(cropRect.width)) × \(Int(cropRect.height))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if actualVideoSize != .zero {
                                let scaleX = actualVideoSize.width / frameSize.width
                                let scaleY = actualVideoSize.height / frameSize.height
                                let actualWidth = Int(cropRect.width * scaleX)
                                let actualHeight = Int(cropRect.height * scaleY)
                                Text("Video: \(actualWidth) × \(actualHeight)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan, lineWidth: 1)
                        )
                        .cornerRadius(6)
                        
                        Spacer()
                    }
                    .padding(.top, 12)
                }
                
                if cropRect == .zero {
                    VStack {
                        VStack(spacing: 4) {
                            Image(systemName: "crop")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            Text("Click and drag to select crop area")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                        )
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStart = value.startLocation
                        }
                        
                        let currentPoint = value.location
                        let x = min(dragStart.x, currentPoint.x)
                        let y = min(dragStart.y, currentPoint.y)
                        let width = abs(currentPoint.x - dragStart.x)
                        let height = abs(currentPoint.y - dragStart.y)
                        
                        cropRect = CGRect(x: x, y: y, width: width, height: height)
                    }
                    .onEnded { _ in
                        isDragging = false
                        
                        // Ensure minimum crop size
                        if cropRect.width < 50 || cropRect.height < 50 {
                            cropRect = .zero
                        }
                    }
            )
        }
        .compositingGroup()
        .onAppear {
            // Initialize with a default crop if none exists
            if cropRect == .zero {
                cropRect = CGRect(
                    x: frameSize.width * 0.1,
                    y: frameSize.height * 0.1,
                    width: frameSize.width * 0.8,
                    height: frameSize.height * 0.8
                )
            }
        }
    }
}

enum TrimError: Error, LocalizedError {
    case ffmpegNotFound
    case ffmpegFailed(String)
    case processStartFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg not found. Please install FFmpeg using Homebrew: brew install ffmpeg"
        case .ffmpegFailed(let output):
            if output.contains("Unknown encoder") || output.contains("libx264") {
                return "FFmpeg missing H.264 encoder. Please reinstall FFmpeg with: brew reinstall ffmpeg"
            }
            return "Video trimming failed. The output may not be compatible with QuickTime Player. Error: \(output)"
        case .processStartFailed(let error):
            return "Failed to start trimming process: \(error.localizedDescription)"
        }
    }
}

// ObservableObject for handling AVPlayer KVO
class PlayerObserver: NSObject, ObservableObject {
    private(set) var player: AVPlayer
    private var timeObserver: Any?
    private var updateCallback: ((Double, Double?, Bool) -> Void)?
    private var isObservingTimeControlStatus = false
    
    override init() {
        self.player = AVPlayer()
        super.init()
        
        // Force initialization of AVFoundation subsystems
        DispatchQueue.main.async {
            self.initializeAVFoundation()
        }
    }
    
    private func initializeAVFoundation() {
        // Force load common AVFoundation classes to initialize the framework
        _ = AVAsset.self
        _ = AVPlayer.self
        _ = AVPlayerItem.self
        _ = AVURLAsset.self
    }
    
    func setupPlayer(url: URL, updateCallback: @escaping (Double, Double?, Bool) -> Void) {
        // Clean up previous observer if exists
        cleanup()
        
        self.updateCallback = updateCallback
        
        // Try to resolve the URL to handle any encoding issues
        let resolvedURL = url.standardizedFileURL
        
        player = AVPlayer(url: resolvedURL)
        
        // Get video duration
        let asset = AVURLAsset(url: resolvedURL)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    updateCallback(0, duration.seconds, false)
                }
            } catch {
                // Handle error silently or show user-friendly message
            }
        }
        
        // Add time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.updateCallback?(time.seconds, nil, self.player.timeControlStatus == .playing)
        }
        
        // Observe player status
        if !isObservingTimeControlStatus {
            player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
            isObservingTimeControlStatus = true
        }
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Safe observer removal
        if isObservingTimeControlStatus {
            player.removeObserver(self, forKeyPath: "timeControlStatus")
            isObservingTimeControlStatus = false
        }
        
        updateCallback = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateCallback?(self.player.currentTime().seconds, nil, self.player.timeControlStatus == .playing)
            }
        }
    }
    
    deinit {
        cleanup()
    }
}

#Preview {
    VideoTrimmerView(
        videoURL: URL(fileURLWithPath: "/path/to/video.mov"),
        onTrimComplete: { _ in },
        onCancel: { }
    )
}