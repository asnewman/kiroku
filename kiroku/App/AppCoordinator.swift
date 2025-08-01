//
//  AppCoordinator.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI

// MARK: - AppCoordinatorProtocol
protocol AppCoordinatorProtocol: AnyObject {
    func start() -> AnyView
}

// MARK: - AppCoordinator
final class AppCoordinator: AppCoordinatorProtocol {
    // MARK: - Properties
    private let diContainer: DIContainer
    private let recordingCoordinator: RecordingCoordinatorProtocol
    private let videoEditingCoordinator: VideoEditingCoordinatorProtocol
    
    // MARK: - Initialization
    init(diContainer: DIContainer) {
        self.diContainer = diContainer
        self.recordingCoordinator = RecordingCoordinator(diContainer: diContainer)
        self.videoEditingCoordinator = VideoEditingCoordinator(diContainer: diContainer)
    }
    
    // MARK: - Public Methods
    @MainActor
    func start() -> AnyView {
        let viewModel = diContainer.makeContentViewModel(
            recordingCoordinator: recordingCoordinator,
            videoEditingCoordinator: videoEditingCoordinator
        )
        return AnyView(ContentView(viewModel: viewModel))
    }
}