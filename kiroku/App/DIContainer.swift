//
//  DIContainer.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - DIContainer
final class DIContainer {
    // MARK: - Utilities
    private lazy var processExecutor: ProcessExecutorProtocol = ProcessExecutor()
    private lazy var ffmpegWrapper: FFmpegWrapperProtocol = FFmpegWrapper(processExecutor: processExecutor)
    private lazy var screenCaptureWrapper: ScreenCaptureWrapperProtocol = ScreenCaptureWrapper(processExecutor: processExecutor)
    
    // MARK: - Repositories
    private lazy var recordingRepository: RecordingRepositoryProtocol = RecordingRepository(fileService: fileManagementService)
    private lazy var bufferRepository: BufferRepositoryProtocol = BufferRepository(fileService: fileManagementService)
    private lazy var settingsRepository: SettingsRepositoryProtocol = SettingsRepository()
    
    // MARK: - Services
    lazy var screenRecordingService: ScreenRecordingServiceProtocol = ScreenRecordingService(
        screenCaptureWrapper: screenCaptureWrapper,
        bufferRepository: bufferRepository,
        videoProcessingService: videoProcessingService,
        permissionService: permissionService,
        settingsRepository: settingsRepository
    )
    
    lazy var videoProcessingService: VideoProcessingServiceProtocol = VideoProcessingService(
        ffmpegWrapper: ffmpegWrapper,
        fileService: fileManagementService
    )
    
    lazy var fileManagementService: FileManagementServiceProtocol = FileManagementService()
    
    lazy var permissionService: PermissionServiceProtocol = PermissionService()
    
    lazy var clipboardService: ClipboardServiceProtocol = ClipboardService()
    
    // MARK: - ViewModels
    @MainActor
    func makeContentViewModel(
        recordingCoordinator: RecordingCoordinatorProtocol,
        videoEditingCoordinator: VideoEditingCoordinatorProtocol
    ) -> ContentViewModel {
        ContentViewModel(
            screenRecordingService: screenRecordingService,
            videoProcessingService: videoProcessingService,
            fileManagementService: fileManagementService,
            permissionService: permissionService,
            clipboardService: clipboardService,
            recordingRepository: recordingRepository,
            recordingCoordinator: recordingCoordinator,
            videoEditingCoordinator: videoEditingCoordinator
        )
    }
    
    @MainActor
    func makeVideoTrimmerViewModel(
        recording: Recording,
        onComplete: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) -> VideoTrimmerViewModel {
        VideoTrimmerViewModel(
            recording: recording,
            videoProcessingService: videoProcessingService,
            onComplete: onComplete,
            onCancel: onCancel
        )
    }
    
    @MainActor
    func makeRecordingRowViewModel(recording: Recording) -> RecordingRowViewModel {
        RecordingRowViewModel(
            recording: recording,
            fileManagementService: fileManagementService
        )
    }
}