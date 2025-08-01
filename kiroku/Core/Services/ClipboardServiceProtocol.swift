//
//  ClipboardServiceProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation

// MARK: - ClipboardDataType
enum ClipboardDataType {
    case video
    case gif
    case image
}

// MARK: - ClipboardServiceProtocol
protocol ClipboardServiceProtocol: AnyObject {
    // MARK: - Methods
    func copyToClipboard(url: URL) async throws
    func copyDataToClipboard(data: Data, type: ClipboardDataType) async throws
}