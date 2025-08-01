//
//  RecordingRowViewModel.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - RecordingRowViewModel
@MainActor
final class RecordingRowViewModel: ObservableObject {
    // MARK: - Properties
    let recording: Recording
    
    // MARK: - Dependencies
    private let fileManagementService: FileManagementServiceProtocol
    
    // MARK: - Initialization
    init(
        recording: Recording,
        fileManagementService: FileManagementServiceProtocol
    ) {
        self.recording = recording
        self.fileManagementService = fileManagementService
    }
    
    // MARK: - Computed Properties
    var recordingName: String {
        recording.fileName
    }
    
    var fileSize: String {
        recording.formattedFileSize
    }
    
    var isGIF: Bool {
        recording.type == .gif
    }
}