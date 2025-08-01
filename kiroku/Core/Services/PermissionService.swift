//
//  PermissionService.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine
import CoreGraphics
import AppKit

// MARK: - PermissionService
final class PermissionService: PermissionServiceProtocol {
    // MARK: - Published Properties
    @Published private var _hasScreenRecordingPermission: Bool?
    
    // MARK: - Publishers
    var hasScreenRecordingPermission: AnyPublisher<Bool, Never> {
        $_hasScreenRecordingPermission
            .compactMap { $0 } // Only emit non-nil values
            .eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        Task {
            _hasScreenRecordingPermission = await checkScreenRecordingPermission()
        }
    }
    
    // MARK: - PermissionServiceProtocol
    func checkScreenRecordingPermission() async -> Bool {
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            await MainActor.run {
                // Only update if the value has changed
                if _hasScreenRecordingPermission != hasPermission {
                    _hasScreenRecordingPermission = hasPermission
                }
            }
            return hasPermission
        } else {
            await MainActor.run {
                if _hasScreenRecordingPermission != true {
                    _hasScreenRecordingPermission = true
                }
            }
            return true
        }
    }
    
    func requestScreenRecordingPermission() async {
        await openSystemPreferences()
    }
    
    func openSystemPreferences() async {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}