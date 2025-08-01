//
//  ScreenRecordingService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - ScreenRecordingService
final class ScreenRecordingService: ScreenRecordingServiceProtocol {
    // MARK: - Published Properties
    @Published private var _isRecording = true
    @Published private var _bufferChunks: [VideoChunk] = []
    @Published private var _exportProgress: Double = 0
    
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
    
    // MARK: - Initialization
    init(
        screenCaptureWrapper: ScreenCaptureWrapperProtocol,
        bufferRepository: BufferRepositoryProtocol,
        videoProcessingService: VideoProcessingServiceProtocol,
        permissionService: PermissionServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.screenCaptureWrapper = screenCaptureWrapper
        self.bufferRepository = bufferRepository
        self.videoProcessingService = videoProcessingService
        self.permissionService = permissionService
        self.settingsRepository = settingsRepository
    }
    
    // MARK: - ScreenRecordingServiceProtocol
    func startContinuousRecording() async throws {
        _isRecording = true
        // Implementation will be added later
    }
    
    func stopRecording() async throws {
        _isRecording = false
        // Implementation will be added later
    }
    
    func exportLastMinute() async throws -> URL {
        _exportProgress = 0.5
        // Placeholder implementation
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Kiroku Recordings")
        let url = recordingsDir.appendingPathComponent("test.mov")
        _exportProgress = 1.0
        return url
    }
    
    func clearBuffer() async throws {
        _bufferChunks.removeAll()
        try await bufferRepository.clearAllChunks()
    }
}