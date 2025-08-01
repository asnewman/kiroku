//
//  ExportConfiguration.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - ExportConfiguration Model
struct ExportConfiguration {
    let format: ExportFormat
    let quality: ExportQuality
    let outputURL: URL
    
    // MARK: - ExportFormat
    enum ExportFormat: String, CaseIterable {
        case mov = "mov"
        case gif = "gif"
        
        var fileExtension: String { rawValue }
    }
    
    // MARK: - ExportQuality
    enum ExportQuality: String, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"
        
        var ffmpegCRF: String {
            switch self {
            case .high: return "18"
            case .medium: return "23"
            case .low: return "28"
            }
        }
        
        var ffmpegPreset: String {
            switch self {
            case .high: return "slow"
            case .medium: return "medium"
            case .low: return "faster"
            }
        }
    }
}