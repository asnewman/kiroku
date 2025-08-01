//
//  CropConfiguration.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - CropConfiguration Model
struct CropConfiguration: Equatable {
    let cropRect: CGRect
    let overlayFrameSize: CGSize
    let actualVideoSize: CGSize
    
    // MARK: - Computed Properties
    var scaledCropRect: CGRect {
        guard overlayFrameSize != .zero, actualVideoSize != .zero else { return cropRect }
        
        let scaleX = actualVideoSize.width / overlayFrameSize.width
        let scaleY = actualVideoSize.height / overlayFrameSize.height
        
        let scaledX = Int(cropRect.origin.x * scaleX)
        let scaledY = Int(cropRect.origin.y * scaleY)
        let scaledWidth = Int(cropRect.width * scaleX)
        let scaledHeight = Int(cropRect.height * scaleY)
        
        // Ensure dimensions are within bounds and even (for H.264)
        let finalX = max(0, min(scaledX, Int(actualVideoSize.width) - 2))
        let finalY = max(0, min(scaledY, Int(actualVideoSize.height) - 2))
        let finalWidth = max(2, min(scaledWidth, Int(actualVideoSize.width) - finalX))
        let finalHeight = max(2, min(scaledHeight, Int(actualVideoSize.height) - finalY))
        
        // Make dimensions even
        let evenWidth = finalWidth - (finalWidth % 2)
        let evenHeight = finalHeight - (finalHeight % 2)
        
        return CGRect(x: finalX, y: finalY, width: evenWidth, height: evenHeight)
    }
    
    var ffmpegCropFilter: String {
        let rect = scaledCropRect
        return "crop=\(Int(rect.width)):\(Int(rect.height)):\(Int(rect.origin.x)):\(Int(rect.origin.y))"
    }
}