//
//  FFmpegWrapperProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - FFmpegWrapperProtocol
protocol FFmpegWrapperProtocol: AnyObject {
    // MARK: - Properties
    var isAvailable: Bool { get }
    var ffmpegPath: String? { get }
    
    // MARK: - Methods
    func trim(
        input: URL,
        output: URL,
        startTime: TimeInterval,
        duration: TimeInterval,
        cropFilter: String?
    ) async throws
    
    func exportGIF(
        input: URL,
        output: URL,
        fps: Int,
        scale: Int
    ) async throws
    
    func mergeVideos(
        inputs: [URL],
        output: URL
    ) async throws
    
    func getVideoDuration(url: URL) async throws -> TimeInterval
    func getVideoSize(url: URL) async throws -> CGSize
}