//
//  kirokuApp.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI

// MARK: - Main App
@main
struct kirokuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let diContainer = DIContainer()
    private lazy var appCoordinator = AppCoordinator(diContainer: diContainer)
    
    // MARK: - NSApplicationDelegate
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }
    
    // MARK: - Private Methods
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Kiroku")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        
        Task { @MainActor in
            let rootView = appCoordinator.start()
            popover?.contentViewController = NSHostingController(rootView: rootView)
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
}
