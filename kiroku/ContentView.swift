//
//  ContentView.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI

// Helper struct for sheet presentation with item-based approach
struct VideoTrimItem: Identifiable {
    let id = UUID()
    let url: URL
    let key: UUID
}

struct ContentView: View {
    @StateObject private var recordingManager = ScreenRecordingManager()
    @StateObject private var webcamPreviewManager = WebcamPreviewManager()
    @State private var showingTrimmer = false
    @State private var selectedVideoURL: URL? // Store the selected URL
    @State private var trimmerKey = UUID() // Force view recreation
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "video.circle")
                    .foregroundColor(.blue)
                Text("Kiroku")
                    .font(.headline)
                Spacer()
                
                // Configure dropdown
                Menu {
                    Button(action: {
                        recordingManager.toggleWebcamOverlay()
                        if recordingManager.webcamOverlayEnabled {
                            webcamPreviewManager.showPreview(at: recordingManager.webcamCornerPosition)
                        } else {
                            webcamPreviewManager.hidePreview()
                        }
                    }) {
                        HStack {
                            Image(systemName: recordingManager.webcamOverlayEnabled ? "checkmark" : "")
                            Text("Overlay Webcam")
                        }
                    }
                    
                    if recordingManager.webcamOverlayEnabled {
                        Divider()
                        
                        Menu("Webcam Position") {
                            ForEach(WebcamCornerPosition.allCases, id: \.self) { position in
                                Button(action: {
                                    recordingManager.setWebcamCornerPosition(position)
                                    webcamPreviewManager.updatePosition(position)
                                }) {
                                    HStack {
                                        Image(systemName: recordingManager.webcamCornerPosition == position ? "checkmark" : "")
                                        Text(position.rawValue)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    Button(action: {
                        recordingManager.toggleMicrophone()
                    }) {
                        HStack {
                            Image(systemName: recordingManager.microphoneEnabled ? "checkmark" : "")
                            Text("Record Audio")
                        }
                    }
                    
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Configure recording settings")
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Recording Controls
            VStack(spacing: 12) {
                if !recordingManager.hasPermission {
                    Button(action: {
                        recordingManager.startRecording() // This will open System Preferences
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Grant Screen Recording Permission")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: {
                        recordingManager.checkPermission()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Check Permission")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        if recordingManager.isRecording {
                            recordingManager.stopRecording()
                            if recordingManager.webcamOverlayEnabled {
                                webcamPreviewManager.showPreview(at: recordingManager.webcamCornerPosition)
                            }
                        } else {
                            webcamPreviewManager.hidePreview()
                            recordingManager.startRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: recordingManager.isRecording ? "stop.circle.fill" : "record.circle")
                                .foregroundColor(recordingManager.isRecording ? .red : .blue)
                            Text(recordingManager.isRecording ? "Stop Recording" : "Start Recording")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(recordingManager.isRecording ? .red : .blue)
                    
                    if recordingManager.isRecording {
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                            Text("Recording...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Recordings List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Past Recordings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(recordingManager.recordings.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if recordingManager.recordings.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No recordings yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(recordingManager.recordings, id: \.self) { recording in
                                RecordingRow(
                                    recording: recording,
                                    onOpen: { recordingManager.openRecording(recording) },
                                    onDelete: { recordingManager.deleteRecording(recording) },
                                    onTrim: {
                                        selectedVideoURL = recording
                                        trimmerKey = UUID()
                                        showingTrimmer = true
                                    },
                                    onExportGIF: {
                                        recordingManager.exportAsGIF(recording) { result in
                                            switch result {
                                            case .success(let gifURL):
                                                print("GIF exported successfully: \(gifURL.path)")
                                                recordingManager.saveRecordings()
                                            case .failure(let error):
                                                print("Failed to export GIF: \(error.localizedDescription)")
                                            }
                                        }
                                    },
                                    onCopyToClipboard: {
                                        recordingManager.copyToClipboard(recording)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
            
            // Quit Button
            Button("Quit Kiroku") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
        .sheet(item: Binding<VideoTrimItem?>(
            get: { selectedVideoURL.map { VideoTrimItem(url: $0, key: trimmerKey) } },
            set: { newValue in
                selectedVideoURL = newValue?.url
                if newValue == nil {
                    showingTrimmer = false
                }
            }
        )) { item in
            VideoTrimmerView(
                videoURL: item.url,
                onTrimComplete: { trimmedURL in
                    recordingManager.recordings.append(trimmedURL)
                    recordingManager.saveRecordings()
                    selectedVideoURL = nil
                    showingTrimmer = false
                },
                onCancel: {
                    selectedVideoURL = nil
                    showingTrimmer = false
                }
            )
            .id(item.key)
        }
    }
}

struct RecordingRow: View {
    let recording: URL
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onTrim: () -> Void
    let onExportGIF: () -> Void
    let onCopyToClipboard: () -> Void
    
    private var recordingName: String {
        recording.deletingPathExtension().lastPathComponent
    }
    
    private var fileSize: String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: recording.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {}
        return ""
    }
    
    private var isGIF: Bool {
        recording.pathExtension.lowercased() == "gif"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Top line: filename and GIF badge
            HStack(spacing: 4) {
                Text(recordingName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if isGIF {
                    Text("GIF")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(3)
                }
                
                Spacer()
            }
            
            // Bottom line: file size and buttons
            HStack(spacing: 4) {
                Text(fileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onOpen) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Open recording")
                
                Menu {
                    if !isGIF {
                        Button(action: onTrim) {
                            Label("Trim", systemImage: "scissors")
                        }
                        
                        Button(action: onExportGIF) {
                            Label("Export as GIF", systemImage: "photo")
                        }
                        
                        Divider()
                    }
                    
                    Button(action: onCopyToClipboard) {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                    }
                    
                    Divider()
                    
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("More options")
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
}
