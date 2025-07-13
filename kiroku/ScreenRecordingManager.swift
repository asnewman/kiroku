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

class ScreenRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var hasPermission = false
    @Published var ffmpegFound = false
    
    private var recordingProcess: Process?
    private var currentRecordingURL: URL?
    private var screenCaptureDeviceIndex: Int?
    private var ffmpegPath: String?
    
    override init() {
        super.init()
        loadRecordings()
        findFFmpegPath()
        detectScreenCaptureDevice()
        checkPermission()
        warmUpAVFoundation()
    }
    
    func checkPermission() {
        hasPermission = hasScreenRecordingPermission()
    }
    
    private func findFFmpegPath() {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",    // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",       // Intel Homebrew
            "/usr/bin/ffmpeg",             // System install
            "/opt/local/bin/ffmpeg"        // MacPorts
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegPath = path
                ffmpegFound = true
                print("Found ffmpeg at: \(path)")
                return
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
                ffmpegPath = output
                ffmpegFound = true
                print("Found ffmpeg via which: \(output)")
                return
            }
        } catch {
            print("Failed to locate ffmpeg with 'which' command: \(error)")
        }
        
        print("Warning: ffmpeg not found in any common locations")
        ffmpegFound = false
        ffmpegPath = "/opt/homebrew/bin/ffmpeg" // Default fallback
    }
    
    private func detectScreenCaptureDevice() {
        guard let ffmpegPath = ffmpegPath else {
            print("Cannot detect screen capture device: ffmpeg not found")
            return
        }
        
        let deviceProcess = Process()
        deviceProcess.executableURL = URL(fileURLWithPath: ffmpegPath)
        deviceProcess.arguments = ["-f", "avfoundation", "-list_devices", "true", "-i", ""]
        
        let pipe = Pipe()
        deviceProcess.standardError = pipe
        deviceProcess.standardOutput = FileHandle.nullDevice
        
        do {
            try deviceProcess.run()
            deviceProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                screenCaptureDeviceIndex = parseScreenCaptureDevice(from: output)
                print("Detected screen capture device index: \(screenCaptureDeviceIndex ?? -1)")
            }
        } catch {
            print("Failed to detect screen capture device: \(error)")
            // Fallback to common device index
            screenCaptureDeviceIndex = 2
        }
    }
    
    private func parseScreenCaptureDevice(from output: String) -> Int? {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Look for lines like "[2] Capture screen 0"
            if line.contains("Capture screen") || line.contains("capture screen") {
                // Extract the device index from [X] format
                let pattern = #"\[(\d+)\]"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range(at: 1), in: line) {
                    if let deviceIndex = Int(line[range]) {
                        return deviceIndex
                    }
                }
            }
        }
        
        return nil
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
        
        // Ensure we have detected a screen capture device
        var deviceIndex = screenCaptureDeviceIndex
        if deviceIndex == nil {
            print("No screen capture device detected. Attempting to re-detect...")
            detectScreenCaptureDevice()
            deviceIndex = screenCaptureDeviceIndex
            guard let finalIndex = deviceIndex else {
                print("Failed to detect screen capture device")
                return
            }
            print("Re-detection successful, using device index: \(finalIndex)")
        }
        
        guard let finalDeviceIndex = deviceIndex else {
            print("Failed to get device index")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let filename = "Screen Recording \(formatter.string(from: Date())).mov"
        
        currentRecordingURL = recordingsDir.appendingPathComponent(filename)
        
        guard let url = currentRecordingURL else { return }
        
        guard let ffmpegPath = ffmpegPath else {
            print("Cannot start recording: ffmpeg not found")
            return
        }
        
        recordingProcess = Process()
        recordingProcess?.executableURL = URL(fileURLWithPath: ffmpegPath)
        // Use ffmpeg to capture screen with avfoundation
        recordingProcess?.arguments = [
            "-f", "avfoundation",
            "-capture_cursor", "1", // Enable cursor capture
            "-i", "\(finalDeviceIndex):none",  // Use detected device index, no audio
            "-r", "30", // 30 fps
            "-vcodec", "libx264",
            "-preset", "ultrafast",
            "-crf", "18",
            "-y", // Overwrite output file without asking
            url.path
        ]
        
        // Capture stderr to see ffmpeg errors
        let pipe = Pipe()
        recordingProcess?.standardError = pipe
        recordingProcess?.standardOutput = FileHandle.nullDevice
        
        recordingProcess?.terminationHandler = { [weak self] process in
            print("Recording process terminated with status: \(process.terminationStatus)")
            
            // Read any error output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty {
                print("FFmpeg error output: \(errorOutput)")
            }
            
            DispatchQueue.main.async {
                self?.isRecording = false
                if let url = self?.currentRecordingURL {
                    print("Checking for recording file at: \(url.path)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if FileManager.default.fileExists(atPath: url.path) {
                            print("Recording file found, adding to list")
                            self?.recordings.append(url)
                            self?.saveRecordings()
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
            try recordingProcess?.run()
            isRecording = true
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            recordingProcess = nil
        }
    }
    
    func stopRecording() {
        guard isRecording, let process = recordingProcess else { return }
        process.terminate()
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
        guard let ffmpegPath = ffmpegPath else {
            completion(.failure(NSError(domain: "FFmpegNotFound", code: 1, userInfo: [NSLocalizedDescriptionKey: "FFmpeg not found"])))
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
}