import SwiftUI
import AVFoundation
import AppKit

class WebcamPreviewWindow: NSWindow {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    init() {
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - windowSize.width - 20,
            y: screenFrame.minY + 20
        )
        
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
}

class WebcamPreviewManager: ObservableObject {
    private var window: WebcamPreviewWindow?
    
    func showPreview() {
        if window == nil {
            window = WebcamPreviewWindow()
        }
        window?.startPreview()
    }
    
    func hidePreview() {
        window?.stopPreview()
    }
}