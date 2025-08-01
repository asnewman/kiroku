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

class ScreenRecordingManager: ObservableObject {
    @Published var isRecording = true  // Always recording
    @Published var recordings: [URL] = []
    @Published var hasPermission = false
    @Published var bufferChunks: [URL] = []  // Rolling buffer of video chunks
    @Published var isExporting = false  // Track export status
    
    private var recordingProcess: Process?
    private var currentRecordingURL: URL?
    private var recordingTimer: Timer?
    private let chunkDuration: TimeInterval = 10.0  // 10 second chunks
    private let bufferDuration: TimeInterval = 120.0  // 2 minute buffer
    private var chunkStartTime: Date?
    
    init() {
        clearBuffer()
        loadRecordings()
        checkPermission()
        
        // Start continuous recording if we have permission
        if hasPermission {
            startContinuousRecording()
        }
    }
    
    func checkPermission() {
        let newPermission = hasScreenRecordingPermission()
        let wasGranted = !hasPermission && newPermission
        hasPermission = newPermission
        
        // Start recording if permission was just granted (but not if already recording)
        if wasGranted && recordingTimer == nil {
            startContinuousRecording()
        }
    }
    
    private func startContinuousRecording() {
        print("startContinuousRecording called, hasPermission: \(hasPermission)")
        guard hasPermission else { 
            print("No permission for screen recording")
            return 
        }
        startNextChunk()
    }
    
    private func startNextChunk() {
        print("startNextChunk called")
        
        // Don't interrupt if already recording - let chunks run their full duration
        if recordingProcess != nil && recordingProcess!.isRunning {
            print("Recording already in progress, skipping")
            return
        }
        
        // Clean old chunks outside buffer window
        cleanOldChunks()
        
        // Start new chunk
        startRecordingChunk()
        
        // Next chunk will be started automatically when this one completes
    }
    
    private func startRecordingChunk() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bufferDir = documentsPath.appendingPathComponent("Kiroku Buffer")
        
        try? FileManager.default.createDirectory(at: bufferDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let filename = "chunk_\(formatter.string(from: Date())).mov"
        
        currentRecordingURL = bufferDir.appendingPathComponent(filename)
        chunkStartTime = Date()
        
        guard let url = currentRecordingURL else { return }
        
        print("Starting chunk recording: \(filename)")
        
        recordingProcess = Process()
        recordingProcess?.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // Use -V flag to set video recording duration in seconds
        recordingProcess?.arguments = ["-v", "-V", String(Int(chunkDuration)), url.path]
        
        // Capture stderr to see screencapture errors
        let pipe = Pipe()
        recordingProcess?.standardError = pipe
        recordingProcess?.standardOutput = FileHandle.nullDevice
        
        recordingProcess?.terminationHandler = { [weak self] process in
            print("🔴 TERMINATION HANDLER CALLED")
            print("Chunk recording terminated with status: \(process.terminationStatus)")
            print("Process termination reason: \(process.terminationReason.rawValue)")
            
            // Read any error output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty {
                print("screencapture error output: \(errorOutput)")
            } else {
                print("No error output from screencapture")
            }
            
            DispatchQueue.main.async {
                if let url = self?.currentRecordingURL {
                    // Wait for the file to be written - timeout should produce a complete file
                    print("🟡 Waiting 2 seconds for file to be written: \(url.path)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🟡 Checking file existence after wait...")
                        if FileManager.default.fileExists(atPath: url.path) {
                            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            print("✅ Chunk file \(url.lastPathComponent) size: \(fileSize) bytes")
                            
                            // Only add to buffer if file has content
                            if fileSize > 0 {
                                self?.bufferChunks.append(url)
                                print("✅ Added chunk to buffer. Total chunks: \(self?.bufferChunks.count ?? 0)")
                                print("Buffer contents: \(self?.bufferChunks.map { $0.lastPathComponent } ?? [])")
                            } else {
                                print("❌ Chunk file is empty, removing")
                                try? FileManager.default.removeItem(at: url)
                            }
                        } else {
                            print("❌ Chunk file does not exist at: \(url.path)")
                            // List what files do exist in the buffer directory
                            let bufferDir = url.deletingLastPathComponent()
                            if let files = try? FileManager.default.contentsOfDirectory(atPath: bufferDir.path) {
                                print("Files in buffer directory: \(files)")
                            }
                        }
                        
                        // Start next chunk after processing current one
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.startNextChunk()
                        }
                    }
                }
                self?.currentRecordingURL = nil
                self?.recordingProcess = nil
            }
        }
        
        do {
            try recordingProcess?.run()
            print("Chunk recording process started successfully")
            
            // Debug: Check if process is running after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let process = self.recordingProcess {
                    print("Process status after 1s: isRunning=\(process.isRunning), processID=\(process.processIdentifier)")
                }
            }
            
            // Debug: Check status after expected duration
            DispatchQueue.main.asyncAfter(deadline: .now() + chunkDuration + 2.0) {
                if let process = self.recordingProcess {
                    print("Process status after \(self.chunkDuration + 2)s: isRunning=\(process.isRunning), terminated=\(process.isRunning ? "no" : "yes")")
                    if !process.isRunning {
                        print("Process terminated but handler may not have fired")
                    }
                }
            }
        } catch {
            print("Failed to start chunk recording: \(error)")
            recordingProcess = nil
        }
    }
    
    private func stopCurrentChunk() {
        // Send SIGTERM to screencapture for graceful shutdown
        if let process = recordingProcess {
            process.terminate()
        }
    }
    
    private func cleanOldChunks() {
        let cutoffTime = Date().addingTimeInterval(-bufferDuration)
        
        bufferChunks = bufferChunks.filter { url in
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let creationDate = attributes[.creationDate] as? Date {
                if creationDate < cutoffTime {
                    // Delete old chunk
                    try? FileManager.default.removeItem(at: url)
                    return false
                }
            }
            return true
        }
    }
    
    private func clearBuffer() {
        print("Clearing buffer directory")
        
        // Stop any ongoing recording
        if recordingProcess != nil {
            stopCurrentChunk()
        }
        
        // Cancel timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Delete all chunks in buffer
        for url in bufferChunks {
            try? FileManager.default.removeItem(at: url)
        }
        bufferChunks.removeAll()
        
        // Also clean the buffer directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bufferDir = documentsPath.appendingPathComponent("Kiroku Buffer")
        
        if FileManager.default.fileExists(atPath: bufferDir.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: bufferDir, includingPropertiesForKeys: nil)
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
                print("Cleared \(files.count) files from buffer directory")
            } catch {
                print("Error clearing buffer directory: \(error)")
            }
        }
    }
    
    func exportLast1Minute() {
        guard !isExporting else { return }
        
        isExporting = true
        print("exportLast1Minute called")
        let exportDuration: TimeInterval = 60.0  // 1 minute
        let cutoffTime = Date().addingTimeInterval(-exportDuration)
        
        print("Buffer chunks count: \(bufferChunks.count)")
        print("Cutoff time: \(cutoffTime)")
        
        // Get chunks from last 1 minute
        let chunksToExport = bufferChunks.filter { url in
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let creationDate = attributes[.creationDate] as? Date {
                print("Chunk \(url.lastPathComponent) created at: \(creationDate), included: \(creationDate >= cutoffTime)")
                return creationDate >= cutoffTime
            }
            return false
        }.sorted { url1, url2 in
            let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 < date2
        }
        
        print("Chunks to export: \(chunksToExport.count)")
        
        guard !chunksToExport.isEmpty else {
            print("No chunks to export within the last 1 minute")
            isExporting = false
            return
        }
        
        // Merge available chunks (current recording will continue)
        mergeChunks(chunksToExport)
    }
    
    private func mergeChunks(_ chunks: [URL]) {
        print("mergeChunks called with \(chunks.count) chunks")
        
        guard !chunks.isEmpty else {
            print("No chunks to merge")
            return
        }
        
        // Find FFmpeg
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        
        var ffmpegPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegPath = path
                break
            }
        }
        
        guard let ffmpegPath = ffmpegPath else {
            print("FFmpeg not found - needed for merging chunks")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let outputURL = recordingsDir.appendingPathComponent("Recording \(formatter.string(from: Date())).mov")
        
        // Create concat list file
        let listPath = FileManager.default.temporaryDirectory.appendingPathComponent("concat_list.txt")
        let listContent = chunks.map { "file '\($0.path)'" }.joined(separator: "\n")
        
        print("Concat list content:\n\(listContent)")
        
        do {
            try listContent.write(to: listPath, atomically: true, encoding: .utf8)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-f", "concat",
                "-safe", "0",
                "-i", listPath.path,
                "-c:v", "libx264",
                "-crf", "28",
                "-preset", "faster",
                "-c:a", "aac",
                "-b:a", "128k",
                "-y",
                outputURL.path
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = FileHandle.nullDevice
            
            process.terminationHandler = { [weak self] process in
                print("FFmpeg merge terminated with status: \(process.terminationStatus)")
                
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    print("FFmpeg output: \(errorOutput)")
                }
                
                try? FileManager.default.removeItem(at: listPath)
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        print("Merge successful, adding to recordings")
                        self?.recordings.append(outputURL)
                        self?.saveRecordings()
                    } else {
                        print("Merge failed with status: \(process.terminationStatus)")
                    }
                    self?.isExporting = false
                }
            }
            
            try process.run()
        } catch {
            print("Failed to merge chunks: \(error)")
            isExporting = false
        }
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
        
        // Also load existing buffer chunks on startup
        let bufferDir = documentsPath.appendingPathComponent("Kiroku Buffer")
        do {
            let files = try FileManager.default.contentsOfDirectory(at: bufferDir, includingPropertiesForKeys: nil)
            bufferChunks = files.filter { $0.pathExtension.lowercased() == "mov" }
            cleanOldChunks()  // Clean old chunks on startup
        } catch {
            // Buffer directory might not exist yet
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
    
    func requestScreenRecordingPermission() {
        openScreenRecordingPreferences()
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
        
        // Apply audio offset if the source has audio
        let paletteArgs = [
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
