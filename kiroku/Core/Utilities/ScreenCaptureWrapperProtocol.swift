//
//  ScreenCaptureWrapperProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - ScreenCaptureWrapperProtocol
protocol ScreenCaptureWrapperProtocol: AnyObject {
    // MARK: - Methods
    func startRecording(
        outputURL: URL,
        duration: TimeInterval,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> CancellableProcess
}

// MARK: - CancellableProcess
protocol CancellableProcess {
    func cancel()
    var isRunning: Bool { get }
}