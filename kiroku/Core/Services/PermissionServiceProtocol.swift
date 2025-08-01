//
//  PermissionServiceProtocol.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import Foundation
import Combine

// MARK: - PermissionServiceProtocol
protocol PermissionServiceProtocol: AnyObject {
    // MARK: - Publishers
    var hasScreenRecordingPermission: AnyPublisher<Bool, Never> { get }
    
    // MARK: - Methods
    func checkScreenRecordingPermission() async -> Bool
    func requestScreenRecordingPermission() async
    func openSystemPreferences() async
}