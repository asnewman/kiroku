//
//  ProcessExecutor.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - ProcessExecutor
final class ProcessExecutor: ProcessExecutorProtocol {
    // MARK: - ProcessExecutorProtocol
    func execute(
        command: String,
        arguments: [String],
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return ProcessResult(
            exitCode: process.terminationStatus,
            standardOutput: output,
            standardError: error
        )
    }
    
    func executeWithProgress(
        command: String,
        arguments: [String],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ProcessResult {
        // For now, just execute without progress tracking
        return try await execute(command: command, arguments: arguments)
    }
}