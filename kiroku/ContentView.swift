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
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Recording Controls
            VStack(spacing: 12) {
                if !recordingManager.ffmpegFound {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("FFmpeg Not Found")
                                .font(.headline)
                        }
                        Text("Please install FFmpeg using Homebrew:\nbrew install ffmpeg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            if let url = URL(string: "https://formulae.brew.sh/formula/ffmpeg") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Install Instructions")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else if !recordingManager.hasPermission {
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
                        } else {
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
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recordingName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(fileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: onOpen) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Open recording")
                
                Button(action: onTrim) {
                    Image(systemName: "scissors")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Trim recording")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete recording")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
}
