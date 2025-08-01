//
//  RecordingCoordinator.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import AppKit

// MARK: - RecordingCoordinatorProtocol
protocol RecordingCoordinatorProtocol: AnyObject {
    func openRecording(_ recording: Recording)
    func shareRecording(_ recording: Recording)
    func showExportOptions(for recording: Recording)
}

// MARK: - RecordingCoordinator
final class RecordingCoordinator: RecordingCoordinatorProtocol {
    // MARK: - Properties
    private let diContainer: DIContainer
    
    // MARK: - Initialization
    init(diContainer: DIContainer) {
        self.diContainer = diContainer
    }
    
    // MARK: - Public Methods
    func openRecording(_ recording: Recording) {
        NSWorkspace.shared.open(recording.url)
    }
    
    func shareRecording(_ recording: Recording) {
        // Implementation for sharing
    }
    
    func showExportOptions(for recording: Recording) {
        // Implementation for export options
    }
}