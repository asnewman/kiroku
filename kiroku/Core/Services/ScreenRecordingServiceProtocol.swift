//
//  ScreenRecordingServiceProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - ScreenRecordingServiceProtocol
protocol ScreenRecordingServiceProtocol: AnyObject {
    // MARK: - Publishers
    var isRecording: AnyPublisher<Bool, Never> { get }
    var bufferChunks: AnyPublisher<[VideoChunk], Never> { get }
    var exportProgress: AnyPublisher<Double, Never> { get }
    
    // MARK: - Methods
    func startContinuousRecording() async throws
    func stopRecording() async throws
    func exportLastMinute() async throws -> URL
    func clearBuffer() async throws
}