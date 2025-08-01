//
//  FFmpegWrapper.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import AVFoundation
import os.log

// MARK: - FFmpegWrapper
final class FFmpegWrapper: FFmpegWrapperProtocol {
    // MARK: - Properties
    var isAvailable: Bool {
        ffmpegPath != nil
    }
    
    var ffmpegPath: String? {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                Logger.debug("Found FFmpeg at: \(path)", category: .process)
                return path
            }
        }
        Logger.error("FFmpeg not found in any standard location", category: .process)
        return nil
    }
    
    // MARK: - Dependencies
    private let processExecutor: ProcessExecutorProtocol
    
    // MARK: - Initialization
    init(processExecutor: ProcessExecutorProtocol) {
        self.processExecutor = processExecutor
    }
    
    // MARK: - FFmpegWrapperProtocol
    func trim(
        input: URL,
        output: URL,
        startTime: TimeInterval,
        duration: TimeInterval,
        cropFilter: String?
    ) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }
        
        var arguments = [
            "-i", input.path,
            "-ss", String(format: "%.2f", startTime),
            "-t", String(format: "%.2f", duration)
        ]
        
        if let cropFilter = cropFilter {
            arguments.append(contentsOf: ["-vf", cropFilter])
        }
        
        arguments.append(contentsOf: [
            "-c:v", "libx264",
            "-c:a", "aac",
            "-preset", "medium",
            "-crf", "18",
            "-movflags", "+faststart",
            "-avoid_negative_ts", "make_zero",
            "-y",
            output.path
        ])
        
        Logger.info("FFmpeg trim: \(input.lastPathComponent) -> \(output.lastPathComponent), start: \(startTime)s, duration: \(duration)s\(cropFilter != nil ? ", with crop" : "")", category: .process)
        Logger.debug("FFmpeg arguments: \(arguments.joined(separator: " "))", category: .process)
        
        let result = try await processExecutor.execute(command: ffmpegPath, arguments: arguments, timeout: nil)
        
        if !result.success {
            Logger.error("FFmpeg trim failed: \(result.standardError)", category: .process)
            throw FFmpegError.processingFailed(result.standardError)
        }
        Logger.info("FFmpeg trim completed successfully", category: .process)
    }
    
    func exportGIF(
        input: URL,
        output: URL,
        fps: Int,
        scale: Int
    ) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }
        
        // Generate palette
        let paletteURL = output.appendingPathExtension("palette.png")
        let paletteArgs = [
            "-i", input.path,
            "-vf", "fps=\(fps),scale=\(scale):-1:flags=lanczos,palettegen=reserve_transparent=0",
            "-y",
            paletteURL.path
        ]
        
        Logger.info("FFmpeg GIF export: generating palette for \(input.lastPathComponent)", category: .process)
        let paletteResult = try await processExecutor.execute(command: ffmpegPath, arguments: paletteArgs, timeout: nil)
        if !paletteResult.success {
            Logger.error("FFmpeg palette generation failed: \(paletteResult.standardError)", category: .process)
            throw FFmpegError.processingFailed(paletteResult.standardError)
        }
        
        // Create GIF
        let gifArgs = [
            "-i", input.path,
            "-i", paletteURL.path,
            "-lavfi", "fps=\(fps),scale=\(scale):-1:flags=lanczos[v];[v][1:v]paletteuse",
            "-y",
            output.path
        ]
        
        Logger.info("FFmpeg GIF export: creating GIF from palette", category: .process)
        let gifResult = try await processExecutor.execute(command: ffmpegPath, arguments: gifArgs, timeout: nil)
        
        // Clean up palette file
        try? FileManager.default.removeItem(at: paletteURL)
        
        if !gifResult.success {
            Logger.error("FFmpeg GIF creation failed: \(gifResult.standardError)", category: .process)
            throw FFmpegError.processingFailed(gifResult.standardError)
        }
        Logger.info("FFmpeg GIF export completed: \(output.lastPathComponent)", category: .process)
    }
    
    func mergeVideos(
        inputs: [URL],
        output: URL
    ) async throws {
        guard let ffmpegPath = ffmpegPath else {
            throw FFmpegError.notFound
        }
        
        Logger.info("FFmpeg merge: concatenating \(inputs.count) videos", category: .process)
        Logger.debug("Input files: \(inputs.map { $0.lastPathComponent })", category: .process)
        
        // Create concat list file
        let listPath = FileManager.default.temporaryDirectory.appendingPathComponent("concat_list.txt")
        let listContent = inputs.map { "file '\($0.path)'" }.joined(separator: "\n")
        
        try listContent.write(to: listPath, atomically: true, encoding: .utf8)
        
        let arguments = [
            "-f", "concat",
            "-safe", "0",
            "-i", listPath.path,
            "-c:v", "libx264",
            "-crf", "28",
            "-preset", "faster",
            "-c:a", "aac",
            "-b:a", "128k",
            "-y",
            output.path
        ]
        
        let result = try await processExecutor.execute(command: ffmpegPath, arguments: arguments, timeout: nil)
        
        // Clean up list file
        try? FileManager.default.removeItem(at: listPath)
        
        if !result.success {
            Logger.error("FFmpeg merge failed: \(result.standardError)", category: .process)
            throw FFmpegError.processingFailed(result.standardError)
        }
        Logger.info("FFmpeg merge completed: \(output.lastPathComponent)", category: .process)
    }
    
    func getVideoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    func getVideoSize(url: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw FFmpegError.processingFailed("No video track found")
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        return naturalSize
    }
}

// MARK: - FFmpegError
enum FFmpegError: LocalizedError {
    case notFound
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "FFmpeg not found. Please install FFmpeg using Homebrew: brew install ffmpeg"
        case .processingFailed(let error):
            return "FFmpeg processing failed: \(error)"
        }
    }
}