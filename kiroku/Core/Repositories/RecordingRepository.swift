//
//  RecordingRepository.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - RecordingRepository
final class RecordingRepository: RecordingRepositoryProtocol {
    // MARK: - Published Properties
    @Published private var _recordings: [Recording] = []
    
    // MARK: - Publishers
    var recordings: AnyPublisher<[Recording], Never> {
        $_recordings.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let fileService: FileManagementServiceProtocol
    
    // MARK: - Initialization
    init(fileService: FileManagementServiceProtocol) {
        self.fileService = fileService
    }
    
    // MARK: - RecordingRepositoryProtocol
    func loadRecordings() async throws {
        let urls = try await fileService.listRecordings()
        
        var recordings: [Recording] = []
        for url in urls {
            let fileSize = try await fileService.getFileSize(at: url)
            let creationDate = try await fileService.getFileCreationDate(at: url)
            let type: Recording.RecordingType = url.pathExtension.lowercased() == "gif" ? .gif : .video
            
            let recording = Recording(
                url: url,
                createdAt: creationDate,
                fileSize: fileSize,
                type: type
            )
            recordings.append(recording)
        }
        
        // Sort by creation date (newest first)
        recordings.sort { $0.createdAt > $1.createdAt }
        
        await MainActor.run {
            _recordings = recordings
        }
    }
    
    func addRecording(_ recording: Recording) async throws {
        await MainActor.run {
            _recordings.insert(recording, at: 0) // Add to beginning
        }
    }
    
    func deleteRecording(_ recording: Recording) async throws {
        try await fileService.deleteFile(at: recording.url)
        await MainActor.run {
            _recordings.removeAll { $0.id == recording.id }
        }
    }
    
    func updateRecording(_ recording: Recording) async throws {
        await MainActor.run {
            if let index = _recordings.firstIndex(where: { $0.id == recording.id }) {
                _recordings[index] = recording
            }
        }
    }
    
    func getRecording(by id: UUID) async throws -> Recording? {
        return _recordings.first { $0.id == id }
    }
}