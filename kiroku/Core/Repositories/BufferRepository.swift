//
//  BufferRepository.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import os.log

// MARK: - BufferRepository
final class BufferRepository: BufferRepositoryProtocol {
    // MARK: - Published Properties
    @Published private var _chunks: [VideoChunk] = []
    
    // MARK: - Publishers
    var chunks: AnyPublisher<[VideoChunk], Never> {
        $_chunks.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let fileService: FileManagementServiceProtocol
    
    // MARK: - Initialization
    init(fileService: FileManagementServiceProtocol) {
        self.fileService = fileService
    }
    
    // MARK: - BufferRepositoryProtocol
    func addChunk(_ chunk: VideoChunk) async throws {
        Logger.info("Adding chunk to buffer: \(chunk.url.lastPathComponent)", category: .buffer)
        await MainActor.run {
            _chunks.append(chunk)
            _chunks.sort { $0.createdAt < $1.createdAt }
            Logger.debug("Buffer now contains \(_chunks.count) chunks", category: .buffer)
        }
    }
    
    func removeChunk(_ chunk: VideoChunk) async throws {
        Logger.info("Removing chunk from buffer: \(chunk.url.lastPathComponent)", category: .buffer)
        try await fileService.deleteFile(at: chunk.url)
        await MainActor.run {
            _chunks.removeAll { $0.id == chunk.id }
            Logger.debug("Buffer now contains \(_chunks.count) chunks", category: .buffer)
        }
    }
    
    func clearAllChunks() async throws {
        Logger.info("Clearing all chunks from buffer (\(_chunks.count) chunks)", category: .buffer)
        for chunk in _chunks {
            try? await fileService.deleteFile(at: chunk.url)
        }
        await MainActor.run {
            _chunks.removeAll()
            Logger.debug("Buffer cleared", category: .buffer)
        }
    }
    
    func getChunksInTimeRange(from startTime: Date, to endTime: Date) async throws -> [VideoChunk] {
        return _chunks.filter { chunk in
            chunk.createdAt >= startTime && chunk.createdAt <= endTime
        }
    }
    
    func cleanExpiredChunks() async throws {
        let expiredChunks = _chunks.filter { $0.isExpired }
        if !expiredChunks.isEmpty {
            Logger.info("Cleaning \(expiredChunks.count) expired chunks from buffer", category: .buffer)
            for chunk in expiredChunks {
                try await removeChunk(chunk)
            }
        }
    }
}