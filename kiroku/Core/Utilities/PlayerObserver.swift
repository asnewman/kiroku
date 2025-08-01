//
//  PlayerObserver.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import AVFoundation

// MARK: - PlayerObserver
class PlayerObserver: NSObject, ObservableObject {
    private(set) var player: AVPlayer
    private var timeObserver: Any?
    private var updateCallback: ((Double, Double?, Bool) -> Void)?
    private var isObservingTimeControlStatus = false
    
    override init() {
        self.player = AVPlayer()
        super.init()
        
        DispatchQueue.main.async {
            self.initializeAVFoundation()
        }
    }
    
    private func initializeAVFoundation() {
        _ = AVAsset.self
        _ = AVPlayer.self
        _ = AVPlayerItem.self
        _ = AVURLAsset.self
    }
    
    func setupPlayer(url: URL, updateCallback: @escaping (Double, Double?, Bool) -> Void) {
        cleanup()
        
        self.updateCallback = updateCallback
        
        let resolvedURL = url.standardizedFileURL
        player = AVPlayer(url: resolvedURL)
        
        let asset = AVURLAsset(url: resolvedURL)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    updateCallback(0, duration.seconds, false)
                }
            } catch {
                // Handle error silently
            }
        }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.updateCallback?(time.seconds, nil, self.player.timeControlStatus == .playing)
        }
        
        if !isObservingTimeControlStatus {
            player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
            isObservingTimeControlStatus = true
        }
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if isObservingTimeControlStatus {
            player.removeObserver(self, forKeyPath: "timeControlStatus")
            isObservingTimeControlStatus = false
        }
        
        updateCallback = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateCallback?(self.player.currentTime().seconds, nil, self.player.timeControlStatus == .playing)
            }
        }
    }
    
    deinit {
        cleanup()
    }
}