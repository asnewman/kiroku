//
//  ScreenCaptureWrapper.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import os.log

// MARK: - ScreenCaptureProcess
private class ScreenCaptureProcess: CancellableProcess {
    private let process: Process
    
    var isRunning: Bool {
        process.isRunning
    }
    
    init(process: Process) {
        self.process = process
    }
    
    func cancel() {
        Logger.debug("Terminating screen capture process", category: .process)
        process.terminate()
    }
}

// MARK: - ScreenCaptureWrapper
final class ScreenCaptureWrapper: ScreenCaptureWrapperProtocol {
    // MARK: - Dependencies
    private let processExecutor: ProcessExecutorProtocol
    
    // MARK: - Initialization
    init(processExecutor: ProcessExecutorProtocol) {
        self.processExecutor = processExecutor
    }
    
    // MARK: - ScreenCaptureWrapperProtocol
    func startRecording(
        outputURL: URL,
        duration: TimeInterval,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> CancellableProcess {
        Logger.info("Starting screen recording - Output: \(outputURL.lastPathComponent), Duration: \(duration)s", category: .recording)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-v", "-V", String(Int(duration)), outputURL.path]
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    Logger.info("Screen recording completed successfully - \(outputURL.lastPathComponent)", category: .recording)
                    completion(.success(()))
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
                    Logger.error("Screen recording failed - Status: \(process.terminationStatus), Error: \(errorOutput)", category: .recording)
                    completion(.failure(ScreenCaptureError.recordingFailed(errorOutput)))
                }
            }
        }
        
        do {
            try process.run()
            Logger.debug("Screen capture process started with PID: \(process.processIdentifier)", category: .process)
        } catch {
            Logger.error("Failed to start screen capture process: \(error.localizedDescription)", category: .recording)
            completion(.failure(error))
        }
        
        return ScreenCaptureProcess(process: process)
    }
}

// MARK: - ScreenCaptureError
enum ScreenCaptureError: LocalizedError {
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed(let error):
            return "Screen recording failed: \(error)"
        }
    }
}