//
//  VideoChunk.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - VideoChunk Model
struct VideoChunk: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let duration: TimeInterval
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        url: URL,
        createdAt: Date = Date(),
        duration: TimeInterval = 10.0
    ) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.duration = duration
    }
    
    // MARK: - Computed Properties
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 120.0 // 2 minutes
    }
    
    var fileName: String {
        url.lastPathComponent
    }
}