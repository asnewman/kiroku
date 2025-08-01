//
//  RecordingRepositoryProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - RecordingRepositoryProtocol
protocol RecordingRepositoryProtocol: AnyObject {
    // MARK: - Publishers
    var recordings: AnyPublisher<[Recording], Never> { get }
    
    // MARK: - Methods
    func loadRecordings() async throws
    func addRecording(_ recording: Recording) async throws
    func deleteRecording(_ recording: Recording) async throws
    func updateRecording(_ recording: Recording) async throws
    func getRecording(by id: UUID) async throws -> Recording?
}