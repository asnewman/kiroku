//
//  ContentViewModel.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import AppKit

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
        Task {
            await permissionService.requestScreenRecordingPermission()
        }
    }
    
    func checkPermission() {
        Task {
            hasPermission = await permissionService.checkScreenRecordingPermission()
        }
    }
    
    func exportLastMinute() {
        Task {
            do {
                isExporting = true
                let url = try await screenRecordingService.exportLastMinute()
                let fileSize = try await fileManagementService.getFileSize(at: url)
                let recording = Recording(url: url, fileSize: fileSize)
                try await recordingRepository.addRecording(recording)
                isExporting = false
            } catch {
                isExporting = false
                // Handle error
            }
        }
    }
    
    func openRecording(_ recording: Recording) {
        recordingCoordinator.openRecording(recording)
    }
    
    func deleteRecording(_ recording: Recording) {
        Task {
            do {
                try await fileManagementService.deleteFile(at: recording.url)
                try await recordingRepository.deleteRecording(recording)
            } catch {
                // Handle error
            }
        }
    }
    
    func showTrimmer(for recording: Recording) {
        selectedRecording = recording
        showingTrimmer = true
    }
    
    func exportAsGIF(_ recording: Recording) {
        Task {
            do {
                let gifURL = try await videoProcessingService.exportAsGIF(url: recording.url)
                let fileSize = try await fileManagementService.getFileSize(at: gifURL)
                let gifRecording = Recording(url: gifURL, fileSize: fileSize, type: .gif)
                try await recordingRepository.addRecording(gifRecording)
            } catch {
                // Handle error
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
        do {
            try await fileManagementService.createDirectoriesIfNeeded()
            try await recordingRepository.loadRecordings()
            hasPermission = await permissionService.checkScreenRecordingPermission()
            
            if hasPermission {
                try await screenRecordingService.startContinuousRecording()
            }
        } catch {
            // Handle error
        }
    }
    
    private func setupBindings() {
        // Bind permission changes
        permissionService.hasScreenRecordingPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPermission in
                self?.hasPermission = hasPermission
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