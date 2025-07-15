//
//  ScreenRecordingManager.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import AVFoundation
import AppKit
import CoreGraphics
import CoreVideo

class ScreenRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var hasPermission = false
    @Published var webcamOverlayEnabled = false
    
    private var recordingProcess: Process?
    private var currentRecordingURL: URL?
    
    // AVFoundation for webcam capture
    private var captureSession: AVCaptureSession?
    private var webcamInput: AVCaptureDeviceInput?
    private var webcamOutput: AVCaptureVideoDataOutput?
    private var webcamVideoWriter: AVAssetWriter?
    private var webcamVideoWriterInput: AVAssetWriterInput?
    private var webcamTempURL: URL?
    private var webcamSessionStarted = false
    
    override init() {
        super.init()
        loadRecordings()
        checkPermission()
        warmUpAVFoundation()
    }
    
    func checkPermission() {
        hasPermission = hasScreenRecordingPermission()
    }
    
    func toggleWebcamOverlay() {
        webcamOverlayEnabled.toggle()
    }
    
    private func setupWebcamCapture() -> Bool {
        guard webcamOverlayEnabled else { return false }
        
        // Find the camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            print("No camera device found")
            return false
        }
        
        do {
            // Create capture session
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .vga640x480
            
            // Create input
            webcamInput = try AVCaptureDeviceInput(device: camera)
            guard let webcamInput = webcamInput,
                  let captureSession = captureSession,
                  captureSession.canAddInput(webcamInput) else {
                print("Cannot add webcam input")
                return false
            }
            captureSession.addInput(webcamInput)
            
            // Create output
            webcamOutput = AVCaptureVideoDataOutput()
            guard let webcamOutput = webcamOutput,
                  captureSession.canAddOutput(webcamOutput) else {
                print("Cannot add webcam output")
                return false
            }
            
            webcamOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            let queue = DispatchQueue(label: "webcam.capture.queue")
            webcamOutput.setSampleBufferDelegate(self, queue: queue)
            captureSession.addOutput(webcamOutput)
            
            return true
        } catch {
            print("Failed to setup webcam capture: \(error)")
            return false
        }
    }
    
    private func startWebcamRecording(outputURL: URL) -> Bool {
        guard let captureSession = captureSession else { return false }
        
        // Create temporary file for webcam recording
        let tempDir = FileManager.default.temporaryDirectory
        webcamTempURL = tempDir.appendingPathComponent("webcam_\(UUID().uuidString).mov")
        
        guard let webcamTempURL = webcamTempURL else { return false }
        
        do {
            // Create asset writer
            webcamVideoWriter = try AVAssetWriter(outputURL: webcamTempURL, fileType: .mov)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 320,
                AVVideoHeightKey: 240,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 1000000
                ]
            ]
            
            webcamVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            webcamVideoWriterInput?.expectsMediaDataInRealTime = true
            
            guard let webcamVideoWriterInput = webcamVideoWriterInput,
                  let webcamVideoWriter = webcamVideoWriter,
                  webcamVideoWriter.canAdd(webcamVideoWriterInput) else {
                print("Cannot add webcam video writer input")
                return false
            }
            
            webcamVideoWriter.add(webcamVideoWriterInput)
            
            // Start the asset writer immediately
            webcamVideoWriter.startWriting()
            webcamSessionStarted = false
            
            // Start capture session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
            
            return true
        } catch {
            print("Failed to start webcam recording: \(error)")
            return false
        }
    }
    
    private func stopWebcamRecording() {
        captureSession?.stopRunning()
        
        // Only mark as finished if the writer is in writing state
        if let writer = webcamVideoWriter, writer.status == .writing {
            webcamVideoWriterInput?.markAsFinished()
            writer.finishWriting {
                print("Webcam recording finished")
            }
        } else {
            print("Webcam writer not in writing state, skipping finishWriting")
        }
    }
    
    private func cleanupWebcamCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        webcamInput = nil
        webcamOutput = nil
        webcamVideoWriter = nil
        webcamVideoWriterInput = nil
        webcamSessionStarted = false
        
        // Clean up temp file
        if let webcamTempURL = webcamTempURL {
            try? FileManager.default.removeItem(at: webcamTempURL)
            self.webcamTempURL = nil
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Check for screen recording permission first
        checkPermission()
        if !hasPermission {
            print("Screen recording permission not granted. Opening System Preferences...")
            openScreenRecordingPreferences()
            return
        }
        
        // screencapture doesn't need device index detection
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let filename = "Screen Recording \(formatter.string(from: Date())).mov"
        
        currentRecordingURL = recordingsDir.appendingPathComponent(filename)
        
        guard let url = currentRecordingURL else { return }
        
        recordingProcess = Process()
        recordingProcess?.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        
        var arguments: [String]
        
        print("Webcam overlay enabled: \(webcamOverlayEnabled)")
        
        if webcamOverlayEnabled {
            // Setup webcam capture for later composition
            if setupWebcamCapture() {
                print("Setting up webcam overlay recording")
                if !startWebcamRecording(outputURL: url) {
                    print("Failed to start webcam recording, falling back to screen-only")
                    cleanupWebcamCapture()
                }
            } else {
                print("Failed to setup webcam capture, falling back to screen-only")
            }
        }
        
        // screencapture arguments: -v for video recording (unlimited time)
        arguments = [
            "-v", // Video recording mode
            url.path
        ]
        
        recordingProcess?.arguments = arguments
        
        // Capture stderr to see screencapture errors
        let pipe = Pipe()
        recordingProcess?.standardError = pipe
        recordingProcess?.standardOutput = FileHandle.nullDevice
        
        recordingProcess?.terminationHandler = { [weak self] process in
            print("Recording process terminated with status: \(process.terminationStatus)")
            
            // Read any error output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty {
                print("screencapture error output: \(errorOutput)")
            }
            
            DispatchQueue.main.async {
                if let url = self?.currentRecordingURL {
                    print("Checking for recording file at: \(url.path)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if FileManager.default.fileExists(atPath: url.path) {
                            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            print("Recording file found with size: \(fileSize) bytes")
                            
                            // Only process if file has content
                            if fileSize > 0 {
                                // If webcam overlay was enabled, composite the videos
                                if self?.webcamOverlayEnabled == true, let webcamURL = self?.webcamTempURL {
                                    print("Starting video composition...")
                                    self?.compositeVideos(screenURL: url, webcamURL: webcamURL) { [weak self] compositeURL in
                                        if let compositeURL = compositeURL {
                                            // Replace the screen recording with the composite
                                            try? FileManager.default.removeItem(at: url)
                                            try? FileManager.default.moveItem(at: compositeURL, to: url)
                                            print("Video composition completed")
                                        } else {
                                            print("Video composition failed")
                                        }
                                        
                                        // Add to recordings list
                                        self?.recordings.append(url)
                                        self?.saveRecordings()
                                        self?.cleanupWebcamCapture()
                                    }
                                } else {
                                    // Standard recording without webcam
                                    print("Adding recording to list (no webcam)")
                                    self?.recordings.append(url)
                                    self?.saveRecordings()
                                }
                            } else {
                                print("Recording file is empty, not adding to list")
                                try? FileManager.default.removeItem(at: url)
                                self?.cleanupWebcamCapture()
                            }
                        } else {
                            print("Recording file not found at expected location")
                            self?.cleanupWebcamCapture()
                        }
                    }
                }
                self?.currentRecordingURL = nil
                self?.recordingProcess = nil
            }
        }
        
        do {
            print("Starting recording to: \(url.path)")
            print("screencapture command: /usr/sbin/screencapture \(arguments.joined(separator: " "))")
            try recordingProcess?.run()
            isRecording = true
            print("Recording started successfully")
            
            // Check if process is actually running after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let process = self.recordingProcess {
                    print("screencapture process running status: \(process.isRunning)")
                    print("screencapture process ID: \(process.processIdentifier)")
                    
                    // Check if file has been created yet
                    if FileManager.default.fileExists(atPath: url.path) {
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                        print("Recording file exists with size: \(fileSize) bytes")
                    } else {
                        print("Recording file not yet created")
                    }
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
            recordingProcess = nil
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        print("Stopping recording...")
        
        // Stop webcam recording if active
        if webcamOverlayEnabled && captureSession?.isRunning == true {
            print("Stopping webcam recording...")
            stopWebcamRecording()
        }
        
        // Send SIGINT (Ctrl+C) to screencapture for graceful shutdown
        if let process = recordingProcess {
            print("Sending SIGINT to screencapture process...")
            process.interrupt()
        }
        
        // Update state immediately to prevent UI lag
        isRecording = false
        print("Recording state updated to false")
    }
    
    private func loadRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            let videoFiles = files.filter { ["mov", "gif"].contains($0.pathExtension.lowercased()) }
            
            recordings = videoFiles.sorted { 
                ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast) > 
                ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast)
            }
        } catch {
            print("Failed to load recordings: \(error)")
        }
    }
    
    func saveRecordings() {
        loadRecordings()
    }
    
    func openRecording(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func deleteRecording(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            recordings.removeAll { $0 == url }
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }
    
    private func hasScreenRecordingPermission() -> Bool {
        // Use CGRequestScreenCaptureAccess to check screen recording permission
        // This is the proper way to check for screen recording permissions on macOS
        if #available(macOS 10.15, *) {
            // For macOS 10.15+, we can use CGPreflightScreenCaptureAccess
            return CGPreflightScreenCaptureAccess()
        } else {
            // For older versions, assume permission is granted
            return true
        }
    }
    
    private func openScreenRecordingPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    func exportAsGIF(_ url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Try to find FFmpeg for GIF conversion
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",    // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",       // Intel Homebrew
            "/usr/bin/ffmpeg",             // System install
            "/opt/local/bin/ffmpeg"        // MacPorts
        ]
        
        var ffmpegPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegPath = path
                break
            }
        }
        
        guard let ffmpegPath = ffmpegPath else {
            completion(.failure(NSError(domain: "FFmpegNotFound", code: 1, userInfo: [NSLocalizedDescriptionKey: "FFmpeg not found - needed for GIF export"])))
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        let gifURL = recordingsDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".gif")
        
        let exportProcess = Process()
        exportProcess.executableURL = URL(fileURLWithPath: ffmpegPath)
        exportProcess.arguments = [
            "-i", url.path,
            "-vf", "fps=15,scale=640:-1:flags=lanczos,palettegen=reserve_transparent=0",
            "-y",
            gifURL.path.replacingOccurrences(of: ".gif", with: "_palette.png")
        ]
        
        let pipe = Pipe()
        exportProcess.standardError = pipe
        exportProcess.standardOutput = FileHandle.nullDevice
        
        exportProcess.terminationHandler = { process in
            if process.terminationStatus == 0 {
                let finalProcess = Process()
                finalProcess.executableURL = URL(fileURLWithPath: ffmpegPath)
                finalProcess.arguments = [
                    "-i", url.path,
                    "-i", gifURL.path.replacingOccurrences(of: ".gif", with: "_palette.png"),
                    "-lavfi", "fps=15,scale=640:-1:flags=lanczos[v];[v][1:v]paletteuse",
                    "-y",
                    gifURL.path
                ]
                
                finalProcess.terminationHandler = { finalProcess in
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: gifURL.path.replacingOccurrences(of: ".gif", with: "_palette.png")))
                    
                    DispatchQueue.main.async {
                        if finalProcess.terminationStatus == 0 {
                            completion(.success(gifURL))
                        } else {
                            completion(.failure(NSError(domain: "GIFExportFailed", code: Int(finalProcess.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF"])))
                        }
                    }
                }
                
                do {
                    try finalProcess.run()
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PaletteGenerationFailed", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to generate palette"])))
                }
            }
        }
        
        do {
            try exportProcess.run()
        } catch {
            completion(.failure(error))
        }
    }
    
    func copyToClipboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if url.pathExtension.lowercased() == "gif" {
            if let gifData = try? Data(contentsOf: url) {
                // Try multiple GIF UTI types for maximum compatibility
                pasteboard.setData(gifData, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
                pasteboard.setData(gifData, forType: NSPasteboard.PasteboardType("public.gif"))
                // Also set as file URL for apps that prefer file references
                pasteboard.setString(url.absoluteString, forType: .fileURL)
            }
        } else {
            // Use file URL approach for better compatibility with apps like Slack
            pasteboard.setString(url.absoluteString, forType: .fileURL)
            
            // Also try setting as movie data with modern UTI types
            if let movieData = try? Data(contentsOf: url) {
                pasteboard.setData(movieData, forType: NSPasteboard.PasteboardType("public.movie"))
            }
        }
    }
    
    private func warmUpAVFoundation() {
        // Create a dummy player to initialize AVFoundation frameworks
        let dummyPlayer = AVPlayer()
        
        // Try to load an existing recording if available to warm up local file handling
        if let firstRecording = recordings.first {
            let asset = AVURLAsset(url: firstRecording)
            let playerItem = AVPlayerItem(asset: asset)
            dummyPlayer.replaceCurrentItem(with: playerItem)
            
            // Quick cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dummyPlayer.replaceCurrentItem(with: nil)
            }
        }
    }
    
    private func compositeVideos(screenURL: URL, webcamURL: URL, completion: @escaping (URL?) -> Void) {
        // Try to find FFmpeg for video composition
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",    // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",       // Intel Homebrew
            "/usr/bin/ffmpeg",             // System install
            "/opt/local/bin/ffmpeg"        // MacPorts
        ]
        
        var ffmpegPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegPath = path
                break
            }
        }
        
        guard let ffmpegPath = ffmpegPath else {
            completion(nil)
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        let compositeURL = recordingsDir.appendingPathComponent("composite_\(UUID().uuidString).mov")
        
        let compositeProcess = Process()
        compositeProcess.executableURL = URL(fileURLWithPath: ffmpegPath)
        compositeProcess.arguments = [
            "-i", screenURL.path,
            "-i", webcamURL.path,
            "-filter_complex", "[1:v]scale=320:240[webcam];[0:v][webcam]overlay=20:20",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-crf", "18",
            "-y",
            compositeURL.path
        ]
        
        compositeProcess.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    print("Video composition successful")
                    completion(compositeURL)
                } else {
                    print("Video composition failed")
                    completion(nil)
                }
            }
        }
        
        do {
            try compositeProcess.run()
        } catch {
            print("Failed to start video composition: \(error)")
            completion(nil)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ScreenRecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let webcamVideoWriterInput = webcamVideoWriterInput,
              let writer = webcamVideoWriter,
              webcamVideoWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        // Start the session with the first frame if writer is ready but session hasn't started
        if writer.status == .writing {
            let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Start session with first frame if not already started
            if !webcamSessionStarted {
                writer.startSession(atSourceTime: startTime)
                webcamSessionStarted = true
                print("Started webcam recording session")
            }
            
            // Append the sample buffer
            webcamVideoWriterInput.append(sampleBuffer)
        }
    }
}