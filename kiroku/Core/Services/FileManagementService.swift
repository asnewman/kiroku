//
//  FileManagementService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - FileManagementService
final class FileManagementService: FileManagementServiceProtocol {
    // MARK: - Properties
    var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Kiroku Recordings")
    }
    
    var bufferDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Kiroku Buffer")
    }
    
    // MARK: - FileManagementServiceProtocol
    func createDirectoriesIfNeeded() async throws {
        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bufferDirectory, withIntermediateDirectories: true)
    }
    
    func deleteFile(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func moveFile(from source: URL, to destination: URL) async throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }
    
    func getFileSize(at url: URL) async throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    func getFileCreationDate(at url: URL) async throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.creationDate] as? Date ?? Date()
    }
    
    func listRecordings() async throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)
        return files.filter { ["mov", "gif"].contains($0.pathExtension.lowercased()) }
    }
    
    func cleanOldBufferFiles(olderThan seconds: TimeInterval) async throws {
        let cutoffDate = Date().addingTimeInterval(-seconds)
        let files = try FileManager.default.contentsOfDirectory(at: bufferDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        for file in files {
            let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            if creationDate < cutoffDate {
                try FileManager.default.removeItem(at: file)
            }
        }
    }
}