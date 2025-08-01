//
//  ScreenRecordingService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import os.log

// MARK: - ScreenRecordingService
final class ScreenRecordingService: ScreenRecordingServiceProtocol {
    // MARK: - Published Properties
    @Published private var _isRecording = false
    @Published private var _bufferChunks: [VideoChunk] = []
    @Published private var _exportProgress: Double = 0
    
    // MARK: - Private Properties
    private var currentRecordingTask: CancellableProcess?
    private var recordingContinuation: Task<Void, Never>?
    private let chunkDuration: TimeInterval = 10.0
    private let bufferDuration: TimeInterval = 120.0
    
    // MARK: - Publishers
    var isRecording: AnyPublisher<Bool, Never> {
        $_isRecording.eraseToAnyPublisher()
    }
    
    var bufferChunks: AnyPublisher<[VideoChunk], Never> {
        $_bufferChunks.eraseToAnyPublisher()
    }
    
    var exportProgress: AnyPublisher<Double, Never> {
        $_exportProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let screenCaptureWrapper: ScreenCaptureWrapperProtocol
    private let bufferRepository: BufferRepositoryProtocol
    private let videoProcessingService: VideoProcessingServiceProtocol
    private let permissionService: PermissionServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let fileManagementService: FileManagementServiceProtocol
    
    // MARK: - Initialization
    init(
        screenCaptureWrapper: ScreenCaptureWrapperProtocol,
        bufferRepository: BufferRepositoryProtocol,
        videoProcessingService: VideoProcessingServiceProtocol,
        permissionService: PermissionServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        fileManagementService: FileManagementServiceProtocol
    ) {
        self.screenCaptureWrapper = screenCaptureWrapper
        self.bufferRepository = bufferRepository
        self.videoProcessingService = videoProcessingService
        self.permissionService = permissionService
        self.settingsRepository = settingsRepository
        self.fileManagementService = fileManagementService
    }
    
    // MARK: - ScreenRecordingServiceProtocol
    func startContinuousRecording() async throws {
        guard !_isRecording else {
            Logger.debug("Recording already in progress, skipping start", category: .recording)
            return
        }
        
        Logger.info("Starting continuous recording", category: .recording)
        _isRecording = true
        
        // Clear old buffer on startup
        try await clearBuffer()
        
        // Start recording loop
        recordingContinuation = Task { [weak self] in
            while self?._isRecording == true {
                await self?.recordNextChunk()
            }
        }
        
        Logger.debug("Continuous recording started", category: .recording)
    }
    
    func stopRecording() async throws {
        Logger.info("Stopping recording", category: .recording)
        _isRecording = false
        
        // Cancel current recording
        currentRecordingTask?.cancel()
        currentRecordingTask = nil
        
        // Cancel recording loop
        recordingContinuation?.cancel()
        recordingContinuation = nil
        
        Logger.debug("Recording stopped", category: .recording)
    }
    
    func exportLastMinute() async throws -> URL {
        Logger.info("Starting export of last minute", category: .export)
        _exportProgress = 0.1
        
        // Get chunks from last minute
        let cutoffTime = Date().addingTimeInterval(-60.0)
        let chunksToExport = _bufferChunks.filter { chunk in
            chunk.createdAt >= cutoffTime
        }.sorted { $0.createdAt < $1.createdAt }
        
        Logger.info("Found \(chunksToExport.count) chunks to export", category: .export)
        
        guard !chunksToExport.isEmpty else {
            throw ScreenRecordingError.noChunksAvailable
        }
        
        _exportProgress = 0.5
        
        // Merge chunks
        let outputURL = try await videoProcessingService.mergeChunks(chunksToExport)
        
        _exportProgress = 1.0
        Logger.info("Export completed - Output: \(outputURL.lastPathComponent)", category: .export)
        return outputURL
    }
    
    func clearBuffer() async throws {
        Logger.info("Clearing buffer - Current chunks: \(_bufferChunks.count)", category: .buffer)
        _bufferChunks.removeAll()
        try await bufferRepository.clearAllChunks()
        Logger.debug("Buffer cleared successfully", category: .buffer)
    }
    
    // MARK: - Private Methods
    private func recordNextChunk() async {
        // Clean old chunks first
        await cleanOldChunks()
        
        // Create chunk file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bufferDir = documentsPath.appendingPathComponent("Kiroku Buffer")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let filename = "chunk_\(formatter.string(from: Date())).mov"
        let chunkURL = bufferDir.appendingPathComponent(filename)
        
        Logger.debug("Recording new chunk: \(filename)", category: .recording)
        
        // Start recording
        currentRecordingTask = screenCaptureWrapper.startRecording(
            outputURL: chunkURL,
            duration: chunkDuration
        ) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    Logger.info("Chunk recorded successfully: \(filename)", category: .recording)
                    
                    // Add chunk to buffer
                    if let fileSize = try? await self?.fileManagementService.getFileSize(at: chunkURL),
                       fileSize > 0 {
                        let chunk = VideoChunk(url: chunkURL, duration: self?.chunkDuration ?? 10.0)
                        try? await self?.bufferRepository.addChunk(chunk)
                        self?._bufferChunks.append(chunk)
                    } else {
                        Logger.error("Chunk file is empty or doesn't exist: \(filename)", category: .recording)
                        try? await self?.fileManagementService.deleteFile(at: chunkURL)
                    }
                    
                case .failure(let error):
                    Logger.error("Failed to record chunk: \(error.localizedDescription)", category: .recording)
                }
            }
        }
        
        // Wait for recording to complete
        await withCheckedContinuation { continuation in
            Task {
                try? await Task.sleep(nanoseconds: UInt64(chunkDuration * 1_000_000_000))
                continuation.resume()
            }
        }
    }
    
    private func cleanOldChunks() async {
        let cutoffTime = Date().addingTimeInterval(-bufferDuration)
        
        let chunksToRemove = _bufferChunks.filter { chunk in
            chunk.createdAt < cutoffTime
        }
        
        for chunk in chunksToRemove {
            Logger.debug("Removing old chunk: \(chunk.url.lastPathComponent)", category: .buffer)
            try? await bufferRepository.removeChunk(chunk)
            _bufferChunks.removeAll { $0.id == chunk.id }
        }
    }
}

// MARK: - ScreenRecordingError
enum ScreenRecordingError: LocalizedError {
    case noChunksAvailable
    
    var errorDescription: String? {
        switch self {
        case .noChunksAvailable:
            return "No recording chunks available for export"
        }
    }
}