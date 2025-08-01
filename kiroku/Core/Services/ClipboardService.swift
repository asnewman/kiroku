//
//  ClipboardService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import AppKit

// MARK: - ClipboardService
final class ClipboardService: ClipboardServiceProtocol {
    // MARK: - ClipboardServiceProtocol
    func copyToClipboard(url: URL) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if url.pathExtension.lowercased() == "gif" {
            if let gifData = try? Data(contentsOf: url) {
                pasteboard.setData(gifData, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
                pasteboard.setData(gifData, forType: NSPasteboard.PasteboardType("public.gif"))
                pasteboard.setString(url.absoluteString, forType: .fileURL)
            }
        } else {
            pasteboard.setString(url.absoluteString, forType: .fileURL)
            
            if let movieData = try? Data(contentsOf: url) {
                pasteboard.setData(movieData, forType: NSPasteboard.PasteboardType("public.movie"))
            }
        }
    }
    
    func copyDataToClipboard(data: Data, type: ClipboardDataType) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch type {
        case .video:
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.movie"))
        case .gif:
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.gif"))
        case .image:
            pasteboard.setData(data, forType: .png)
        }
    }
}