//
//  ProcessExecutorProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - ProcessExecutorProtocol
protocol ProcessExecutorProtocol: AnyObject {
    // MARK: - Methods
    func execute(
        command: String,
        arguments: [String],
        timeout: TimeInterval?
    ) async throws -> ProcessResult
    
    func executeWithProgress(
        command: String,
        arguments: [String],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ProcessResult
}

// MARK: - ProcessResult
struct ProcessResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
    let success: Bool
    
    init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.success = exitCode == 0
    }
}