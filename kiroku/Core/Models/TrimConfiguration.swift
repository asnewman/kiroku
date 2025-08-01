//
//  TrimConfiguration.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - TrimConfiguration Model
struct TrimConfiguration: Equatable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let cropConfiguration: CropConfiguration?
    
    // MARK: - Computed Properties
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var isValid: Bool {
        endTime > startTime && duration > 0
    }
    
    // MARK: - Formatting
    var formattedStartTime: String {
        formatTime(startTime)
    }
    
    var formattedEndTime: String {
        formatTime(endTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}