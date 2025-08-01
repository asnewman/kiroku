//
//  ContentViewModel.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import AppKit
import os.log

// MARK: - ContentViewModel
@MainActor
final class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var recordings: [Recording] = []
    @Published private(set) var isRecording = false
    @Published private(set) var hasPermission = false
    @Published private(set) var isExporting = false
    @Published private(set) var bufferChunksCount = 0
    @Published var selectedRecording: Recording?
    @Published var showingTrimmer = false
    
    // MARK: - Dependencies
    private let screenRecordingService: ScreenRecordingServiceProtocol
    private let videoProcessingService: VideoProcessingServiceProtocol
    private let fileManagementService: FileManagementServiceProtocol
    private let permissionService: PermissionServiceProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let recordingCoordinator: RecordingCoordinatorProtocol
    private let videoEditingCoordinator: VideoEditingCoordinatorProtocol
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        screenRecordingService: ScreenRecordingServiceProtocol,
        videoProcessingService: VideoProcessingServiceProtocol,
        fileManagementService: FileManagementServiceProtocol,
        permissionService: PermissionServiceProtocol,
        clipboardService: ClipboardServiceProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        recordingCoordinator: RecordingCoordinatorProtocol,
        videoEditingCoordinator: VideoEditingCoordinatorProtocol
    ) {
        self.screenRecordingService = screenRecordingService
        self.videoProcessingService = videoProcessingService
        self.fileManagementService = fileManagementService
        self.permissionService = permissionService
        self.clipboardService = clipboardService
        self.recordingRepository = recordingRepository
        self.recordingCoordinator = recordingCoordinator
        self.videoEditingCoordinator = videoEditingCoordinator
        
        setupBindings()
        Task {
            await initialize()
        }
    }
    
    // MARK: - Public Methods
    func requestPermission() {
        Logger.info("User requested screen recording permission", category: .permissions)
        Task {
            await permissionService.requestScreenRecordingPermission()
        }
    }
    
    func checkPermission() {
        Task {
            hasPermission = await permissionService.checkScreenRecordingPermission()
            Logger.info("Permission check result: \(hasPermission)", category: .permissions)
        }
    }
    
    func exportLastMinute() {
        Logger.info("User triggered export last minute", category: .ui)
        Task {
            do {
                isExporting = true
                let url = try await screenRecordingService.exportLastMinute()
                let fileSize = try await fileManagementService.getFileSize(at: url)
                let recording = Recording(url: url, fileSize: fileSize)
                try await recordingRepository.addRecording(recording)
                isExporting = false
                Logger.info("Export completed successfully", category: .ui)
            } catch {
                isExporting = false
                Logger.error("Export failed: \(error.localizedDescription)", category: .ui)
            }
        }
    }
    
    func openRecording(_ recording: Recording) {
        recordingCoordinator.openRecording(recording)
    }
    
    func deleteRecording(_ recording: Recording) {
        Logger.info("User deleting recording: \(recording.url.lastPathComponent)", category: .ui)
        Task {
            do {
                try await fileManagementService.deleteFile(at: recording.url)
                try await recordingRepository.deleteRecording(recording)
            } catch {
                Logger.error("Failed to delete recording: \(error.localizedDescription)", category: .ui)
            }
        }
    }
    
    func showTrimmer(for recording: Recording) {
        Logger.info("Opening trimmer for: \(recording.url.lastPathComponent)", category: .ui)
        selectedRecording = recording
        showingTrimmer = true
    }
    
    func exportAsGIF(_ recording: Recording) {
        Logger.info("User exporting as GIF: \(recording.url.lastPathComponent)", category: .ui)
        Task {
            do {
                let gifURL = try await videoProcessingService.exportAsGIF(url: recording.url)
                let fileSize = try await fileManagementService.getFileSize(at: gifURL)
                let gifRecording = Recording(url: gifURL, fileSize: fileSize, type: .gif)
                try await recordingRepository.addRecording(gifRecording)
            } catch {
                Logger.error("GIF export failed: \(error.localizedDescription)", category: .ui)
            }
        }
    }
    
    func copyToClipboard(_ recording: Recording) {
        Task {
            do {
                try await clipboardService.copyToClipboard(url: recording.url)
            } catch {
                // Handle error
            }
        }
    }
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Private Methods
    private func initialize() async {
        Logger.info("Initializing ContentViewModel", category: .ui)
        do {
            try await fileManagementService.createDirectoriesIfNeeded()
            try await recordingRepository.loadRecordings()
            // Permission check and recording start will be handled by setupBindings
        } catch {
            Logger.error("Initialization failed: \(error.localizedDescription)", category: .ui)
        }
    }
    
    private func setupBindings() {
        // Bind permission changes
        permissionService.hasScreenRecordingPermission
            .removeDuplicates() // Prevent duplicate permission status updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPermission in
                self?.hasPermission = hasPermission
                Logger.info("Permission status changed: \(hasPermission)", category: .permissions)
                if hasPermission {
                    Task {
                        try? await self?.screenRecordingService.startContinuousRecording()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind recording state
        screenRecordingService.isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        // Bind buffer chunks
        screenRecordingService.bufferChunks
            .receive(on: DispatchQueue.main)
            .map { $0.count }
            .assign(to: &$bufferChunksCount)
        
        // Bind recordings
        recordingRepository.recordings
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordings)
    }
}