import SwiftUI
import AVFoundation
import AppKit

class WebcamPreviewWindow: NSWindow {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    init(position: WebcamCornerPosition = .bottomRight) {
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let origin = Self.calculateOrigin(for: position, windowSize: windowSize, screenFrame: screenFrame)
        
        super.init(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .black
        self.hasShadow = true
        
        // Make window circular
        self.isOpaque = false
        self.backgroundColor = .clear
        
        setupWebcam()
    }
    
    private func setupWebcam() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let captureSession = captureSession else {
            print("Failed to setup webcam")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
            contentView.wantsLayer = true
            
            // Create circular mask
            let maskLayer = CAShapeLayer()
            let diameter = min(contentView.bounds.width, contentView.bounds.height)
            let radius = diameter / 2
            let center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
            let path = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter), transform: nil)
            maskLayer.path = path
            
            contentView.layer?.mask = maskLayer
            contentView.layer?.addSublayer(previewLayer)
            previewLayer.frame = contentView.bounds
            
            self.contentView = contentView
        }
        
        captureSession.startRunning()
    }
    
    func startPreview() {
        captureSession?.startRunning()
        self.orderFront(nil)
    }
    
    func stopPreview() {
        captureSession?.stopRunning()
        self.orderOut(nil)
    }
    
    deinit {
        captureSession?.stopRunning()
    }
    
    func updatePosition(_ position: WebcamCornerPosition) {
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let origin = Self.calculateOrigin(for: position, windowSize: windowSize, screenFrame: screenFrame)
        self.setFrameOrigin(origin)
    }
    
    private static func calculateOrigin(for position: WebcamCornerPosition, windowSize: NSSize, screenFrame: NSRect) -> NSPoint {
        let padding: CGFloat = 20
        
        switch position {
        case .bottomRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
        case .bottomLeft:
            return NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .topRight:
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topLeft:
            return NSPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        }
    }
}

class WebcamPreviewManager: ObservableObject {
    private var window: WebcamPreviewWindow?
    private var currentPosition: WebcamCornerPosition = .bottomRight
    
    func showPreview(at position: WebcamCornerPosition = .bottomRight) {
        if window == nil {
            window = WebcamPreviewWindow(position: position)
            currentPosition = position
        } else if currentPosition != position {
            window?.updatePosition(position)
            currentPosition = position
        }
        window?.startPreview()
    }
    
    func hidePreview() {
        window?.stopPreview()
    }
    
    func updatePosition(_ position: WebcamCornerPosition) {
        currentPosition = position
        window?.updatePosition(position)
    }
}