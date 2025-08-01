//
//  SettingsRepositoryProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - SettingsRepositoryProtocol
protocol SettingsRepositoryProtocol: AnyObject {
    // MARK: - Publishers
    var chunkDuration: AnyPublisher<TimeInterval, Never> { get }
    var bufferDuration: AnyPublisher<TimeInterval, Never> { get }
    var exportQuality: AnyPublisher<ExportConfiguration.ExportQuality, Never> { get }
    
    // MARK: - Methods
    func updateChunkDuration(_ duration: TimeInterval) async throws
    func updateBufferDuration(_ duration: TimeInterval) async throws
    func updateExportQuality(_ quality: ExportConfiguration.ExportQuality) async throws
    func resetToDefaults() async throws
}