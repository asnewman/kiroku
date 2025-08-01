//
//  VideoProcessingService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import AVFoundation

// MARK: - VideoProcessingService
final class VideoProcessingService: VideoProcessingServiceProtocol {
    // MARK: - Published Properties
    @Published private var _processingProgress: Double = 0
    
    // MARK: - Publishers
    var processingProgress: AnyPublisher<Double, Never> {
        $_processingProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let ffmpegWrapper: FFmpegWrapperProtocol
    private let fileService: FileManagementServiceProtocol
    
    // MARK: - Initialization
    init(
        ffmpegWrapper: FFmpegWrapperProtocol,
        fileService: FileManagementServiceProtocol
    ) {
        self.ffmpegWrapper = ffmpegWrapper
        self.fileService = fileService
    }
    
    // MARK: - VideoProcessingServiceProtocol
    func trimVideo(url: URL, configuration: TrimConfiguration) async throws -> URL {
        _processingProgress = 0.0
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let baseFilename = configuration.cropConfiguration != nil ? "Trimmed+Cropped" : "Trimmed"
        let trimmedFilename = "\(baseFilename) - \(formatter.string(from: Date())).mov"
        let outputURL = recordingsDir.appendingPathComponent(trimmedFilename)
        
        let cropFilter = configuration.cropConfiguration?.ffmpegCropFilter
        
        try await ffmpegWrapper.trim(
            input: url,
            output: outputURL,
            startTime: configuration.startTime,
            duration: configuration.duration,
            cropFilter: cropFilter
        )
        
        _processingProgress = 1.0
        return outputURL
    }
    
    func exportAsGIF(url: URL) async throws -> URL {
        _processingProgress = 0.0
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        let gifURL = recordingsDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".gif")
        
        try await ffmpegWrapper.exportGIF(
            input: url,
            output: gifURL,
            fps: 15,
            scale: 640
        )
        
        _processingProgress = 1.0
        return gifURL
    }
    
    func mergeChunks(_ chunks: [VideoChunk]) async throws -> URL {
        _processingProgress = 0.0
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let outputURL = recordingsDir.appendingPathComponent("Recording \(formatter.string(from: Date())).mov")
        
        let urls = chunks.map { $0.url }
        try await ffmpegWrapper.mergeVideos(inputs: urls, output: outputURL)
        
        _processingProgress = 1.0
        return outputURL
    }
    
    func getVideoDuration(url: URL) async throws -> TimeInterval {
        return try await ffmpegWrapper.getVideoDuration(url: url)
    }
    
    func getVideoSize(url: URL) async throws -> CGSize {
        return try await ffmpegWrapper.getVideoSize(url: url)
    }
}