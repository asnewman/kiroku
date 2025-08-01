//
//  SettingsRepository.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - SettingsRepository
final class SettingsRepository: SettingsRepositoryProtocol {
    // MARK: - Published Properties
    @Published private var _chunkDuration: TimeInterval = 10.0
    @Published private var _bufferDuration: TimeInterval = 120.0
    @Published private var _exportQuality: ExportConfiguration.ExportQuality = .medium
    
    // MARK: - Publishers
    var chunkDuration: AnyPublisher<TimeInterval, Never> {
        $_chunkDuration.eraseToAnyPublisher()
    }
    
    var bufferDuration: AnyPublisher<TimeInterval, Never> {
        $_bufferDuration.eraseToAnyPublisher()
    }
    
    var exportQuality: AnyPublisher<ExportConfiguration.ExportQuality, Never> {
        $_exportQuality.eraseToAnyPublisher()
    }
    
    // MARK: - SettingsRepositoryProtocol
    func updateChunkDuration(_ duration: TimeInterval) async throws {
        await MainActor.run {
            _chunkDuration = duration
        }
        UserDefaults.standard.set(duration, forKey: "chunkDuration")
    }
    
    func updateBufferDuration(_ duration: TimeInterval) async throws {
        await MainActor.run {
            _bufferDuration = duration
        }
        UserDefaults.standard.set(duration, forKey: "bufferDuration")
    }
    
    func updateExportQuality(_ quality: ExportConfiguration.ExportQuality) async throws {
        await MainActor.run {
            _exportQuality = quality
        }
        UserDefaults.standard.set(quality.rawValue, forKey: "exportQuality")
    }
    
    func resetToDefaults() async throws {
        await MainActor.run {
            _chunkDuration = 10.0
            _bufferDuration = 120.0
            _exportQuality = .medium
        }
        
        UserDefaults.standard.removeObject(forKey: "chunkDuration")
        UserDefaults.standard.removeObject(forKey: "bufferDuration")
        UserDefaults.standard.removeObject(forKey: "exportQuality")
    }
    
    // MARK: - Initialization
    init() {
        loadSettings()
    }
    
    // MARK: - Private Methods
    private func loadSettings() {
        _chunkDuration = UserDefaults.standard.object(forKey: "chunkDuration") as? TimeInterval ?? 10.0
        _bufferDuration = UserDefaults.standard.object(forKey: "bufferDuration") as? TimeInterval ?? 120.0
        
        if let qualityString = UserDefaults.standard.string(forKey: "exportQuality"),
           let quality = ExportConfiguration.ExportQuality(rawValue: qualityString) {
            _exportQuality = quality
        } else {
            _exportQuality = .medium
        }
    }
}