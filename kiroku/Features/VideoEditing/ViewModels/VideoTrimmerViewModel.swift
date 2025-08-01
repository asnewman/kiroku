//
//  VideoTrimmerViewModel.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import AVFoundation

// MARK: - VideoTrimmerViewModel
@MainActor
final class VideoTrimmerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var startTime: Double = 0
    @Published var endTime: Double = 0
    @Published var isPlaying = false
    @Published var isTrimming = false
    @Published var trimError: String?
    @Published var cropEnabled = false
    @Published var cropRect: CGRect = .zero
    @Published var videoSize: CGSize = .zero
    @Published var actualVideoSize: CGSize = .zero
    
    // MARK: - Properties
    let recording: Recording
    let player: AVPlayer
    
    // MARK: - Dependencies
    private let videoProcessingService: VideoProcessingServiceProtocol
    private let onComplete: (URL) -> Void
    private let onCancel: () -> Void
    
    // MARK: - Private Properties
    private var playerObserver: PlayerObserver?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        recording: Recording,
        videoProcessingService: VideoProcessingServiceProtocol,
        onComplete: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.recording = recording
        self.videoProcessingService = videoProcessingService
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.player = AVPlayer(url: recording.url)
        
        setupPlayer()
    }
    
    // MARK: - Public Methods
    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func seekTo(time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
    }
    
    func setStartTimeToCurrentTime() {
        startTime = currentTime
    }
    
    func setEndTimeToCurrentTime() {
        endTime = currentTime
    }
    
    func toggleCrop() {
        cropEnabled.toggle()
        if !cropEnabled {
            cropRect = .zero
        }
    }
    
    func resetCrop() {
        cropRect = .zero
    }
    
    func trimVideo() {
        guard !isTrimming else { return }
        
        isTrimming = true
        trimError = nil
        
        Task {
            do {
                let cropConfig = cropEnabled && cropRect != .zero
                    ? CropConfiguration(
                        cropRect: cropRect,
                        overlayFrameSize: CGSize(width: 400, height: 300),
                        actualVideoSize: actualVideoSize
                    )
                    : nil
                
                let trimConfig = TrimConfiguration(
                    startTime: startTime,
                    endTime: endTime,
                    cropConfiguration: cropConfig
                )
                
                let trimmedURL = try await videoProcessingService.trimVideo(
                    url: recording.url,
                    configuration: trimConfig
                )
                
                isTrimming = false
                onComplete(trimmedURL)
            } catch {
                isTrimming = false
                trimError = error.localizedDescription
            }
        }
    }
    
    func cancel() {
        playerObserver?.cleanup()
        onCancel()
    }
    
    // MARK: - Private Methods
    private func setupPlayer() {
        playerObserver = PlayerObserver()
        playerObserver?.setupPlayer(url: recording.url) { [weak self] currentTime, duration, isPlaying in
            self?.currentTime = currentTime
            if let duration = duration {
                self?.duration = duration
                self?.endTime = duration
            }
            self?.isPlaying = isPlaying
        }
        
        // Get video dimensions
        Task {
            do {
                actualVideoSize = try await videoProcessingService.getVideoSize(url: recording.url)
            } catch {
                // Handle error
            }
        }
    }
    
    deinit {
        playerObserver?.cleanup()
    }
}