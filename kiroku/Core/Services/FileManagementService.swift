//
//  FileManagementService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import os.log

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
        Logger.info("Creating directories if needed", category: .fileSystem)
        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        Logger.debug("Recordings directory: \(recordingsDirectory.path)", category: .fileSystem)
        try FileManager.default.createDirectory(at: bufferDirectory, withIntermediateDirectories: true)
        Logger.debug("Buffer directory: \(bufferDirectory.path)", category: .fileSystem)
    }
    
    func deleteFile(at url: URL) async throws {
        Logger.debug("Deleting file: \(url.lastPathComponent)", category: .fileSystem)
        try FileManager.default.removeItem(at: url)
    }
    
    func moveFile(from source: URL, to destination: URL) async throws {
        Logger.info("Moving file from \(source.lastPathComponent) to \(destination.lastPathComponent)", category: .fileSystem)
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
        Logger.info("Cleaning buffer files older than \(seconds)s", category: .fileSystem)
        let cutoffDate = Date().addingTimeInterval(-seconds)
        let files = try FileManager.default.contentsOfDirectory(at: bufferDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        var deletedCount = 0
        for file in files {
            let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            if creationDate < cutoffDate {
                Logger.debug("Deleting old buffer file: \(file.lastPathComponent)", category: .fileSystem)
                try FileManager.default.removeItem(at: file)
                deletedCount += 1
            }
        }
        if deletedCount > 0 {
            Logger.info("Cleaned \(deletedCount) old buffer files", category: .fileSystem)
        }
    }
}