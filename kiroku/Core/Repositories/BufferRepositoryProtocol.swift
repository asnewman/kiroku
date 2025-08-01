//
//  BufferRepositoryProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - BufferRepositoryProtocol
protocol BufferRepositoryProtocol: AnyObject {
    // MARK: - Publishers
    var chunks: AnyPublisher<[VideoChunk], Never> { get }
    
    // MARK: - Methods
    func addChunk(_ chunk: VideoChunk) async throws
    func removeChunk(_ chunk: VideoChunk) async throws
    func clearAllChunks() async throws
    func getChunksInTimeRange(from startTime: Date, to endTime: Date) async throws -> [VideoChunk]
    func cleanExpiredChunks() async throws
}