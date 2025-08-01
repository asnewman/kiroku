//
//  VideoEditingCoordinator.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI

// MARK: - VideoEditingCoordinatorProtocol
protocol VideoEditingCoordinatorProtocol: AnyObject {
    func showVideoTrimmer(
        for recording: Recording,
        onComplete: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) -> AnyView
}

// MARK: - VideoEditingCoordinator
final class VideoEditingCoordinator: VideoEditingCoordinatorProtocol {
    // MARK: - Properties
    private let diContainer: DIContainer
    
    // MARK: - Initialization
    init(diContainer: DIContainer) {
        self.diContainer = diContainer
    }
    
    // MARK: - Public Methods
    func showVideoTrimmer(
        for recording: Recording,
        onComplete: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) -> AnyView {
        // Temporary: use old VideoTrimmerView interface until refactored
        return AnyView(VideoTrimmerView(
            videoURL: recording.url,
            onTrimComplete: onComplete,
            onCancel: onCancel
        ))
    }
}