//
//  ScreenCaptureWrapper.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-v", "-V", String(Int(duration)), outputURL.path]
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(.success(()))
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
                    completion(.failure(ScreenCaptureError.recordingFailed(errorOutput)))
                }
            }
        }
        
        do {
            try process.run()
        } catch {
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