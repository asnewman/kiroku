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

enum WebcamCornerPosition: String, CaseIterable {
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    case topRight = "Top Right"
    case topLeft = "Top Left"
}

class ScreenRecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var hasPermission = false
    @Published var hasMicrophonePermission = false
    @Published var webcamOverlayEnabled = false
    @Published var microphoneEnabled = false
    @Published var webcamCornerPosition: WebcamCornerPosition = .bottomRight
    @Published var audioOffset: Double = 3.0  // Audio offset in seconds
    
    private var recordingProcess: Process?
    private var currentRecordingURL: URL?
    
    init() {
        loadRecordings()
        checkPermission()
        checkMicrophonePermission()
    }
    
    func checkPermission() {
        hasPermission = hasScreenRecordingPermission()
    }
    
    func checkMicrophonePermission() {
        hasMicrophonePermission = hasMicrophoneAccess()
    }
    
    func toggleWebcamOverlay() {
        webcamOverlayEnabled.toggle()
    }
    
    func setWebcamCornerPosition(_ position: WebcamCornerPosition) {
        webcamCornerPosition = position
    }
    
    func toggleMicrophone() {
        microphoneEnabled.toggle()
        
        // Request microphone permission if needed
        if microphoneEnabled && !hasMicrophonePermission {
            requestMicrophonePermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                    if !granted {
                        self?.microphoneEnabled = false
                    }
                }
            }
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
        
        // Check microphone permission if microphone is enabled
        if microphoneEnabled {
            checkMicrophonePermission()
            if !hasMicrophonePermission {
                print("Microphone permission not granted but microphone recording is enabled")
                // Continue without microphone recording
                microphoneEnabled = false
            }
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
        
        
        // screencapture arguments: -v for video recording (unlimited time)
        if microphoneEnabled && hasMicrophonePermission {
            arguments = [
                "-v", // Video recording mode
                "-g", // Capture audio using default input
                url.path
            ]
        } else {
            arguments = [
                "-v", // Video recording mode
                url.path
            ]
        }
        
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
                                // Standard recording
                                print("Adding recording to list")
                                self?.recordings.append(url)
                                self?.saveRecordings()
                            } else {
                                print("Recording file is empty, not adding to list")
                                try? FileManager.default.removeItem(at: url)
                            }
                        } else {
                            print("Recording file not found at expected location")
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
    
    private func hasMicrophoneAccess() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
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
        
        // Apply audio offset if the source has audio
        var paletteArgs = [
            "-i", url.path,
            "-vf", "fps=15,scale=640:-1:flags=lanczos,palettegen=reserve_transparent=0",
            "-y",
            gifURL.path.replacingOccurrences(of: ".gif", with: "_palette.png")
        ]
        
        // For audio offset, we apply it during the final GIF creation step
        exportProcess.arguments = paletteArgs
        
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
    
}
