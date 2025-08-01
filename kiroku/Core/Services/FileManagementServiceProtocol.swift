//
//  FileManagementServiceProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - FileManagementServiceProtocol
protocol FileManagementServiceProtocol: AnyObject {
    // MARK: - Properties
    var recordingsDirectory: URL { get }
    var bufferDirectory: URL { get }
    
    // MARK: - Methods
    func createDirectoriesIfNeeded() async throws
    func deleteFile(at url: URL) async throws
    func moveFile(from source: URL, to destination: URL) async throws
    func getFileSize(at url: URL) async throws -> Int64
    func getFileCreationDate(at url: URL) async throws -> Date
    func listRecordings() async throws -> [URL]
    func cleanOldBufferFiles(olderThan seconds: TimeInterval) async throws
}