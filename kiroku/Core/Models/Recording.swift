//
//  Recording.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - Recording Model
struct Recording: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let duration: TimeInterval
    let fileSize: Int64
    let type: RecordingType
    
    // MARK: - RecordingType
    enum RecordingType: String, Codable {
        case video = "video"
        case gif = "gif"
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        url: URL,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        type: RecordingType = .video
    ) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.duration = duration
        self.fileSize = fileSize
        self.type = type
    }
    
    // MARK: - Computed Properties
    var fileName: String {
        url.deletingPathExtension().lastPathComponent
    }
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}