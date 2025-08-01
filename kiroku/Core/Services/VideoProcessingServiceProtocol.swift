//
//  VideoProcessingServiceProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - VideoProcessingServiceProtocol
protocol VideoProcessingServiceProtocol: AnyObject {
    // MARK: - Publishers
    var processingProgress: AnyPublisher<Double, Never> { get }
    
    // MARK: - Methods
    func trimVideo(url: URL, configuration: TrimConfiguration) async throws -> URL
    func exportAsGIF(url: URL) async throws -> URL
    func mergeChunks(_ chunks: [VideoChunk]) async throws -> URL
    func getVideoDuration(url: URL) async throws -> TimeInterval
    func getVideoSize(url: URL) async throws -> CGSize
}