//
//  ContentView.swift
//  kiroku
//
//  Created by Ashley Newman on 7/13/25.
//

import SwiftUI

// MARK: - Helper struct for sheet presentation
struct VideoTrimItem: Identifiable {
    let id = UUID()
    let url: URL
    let key: UUID
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    
    // MARK: - Initialization
    init(viewModel: ContentViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            headerView
            recordingControlsView
            Divider()
            recordingsListView
            Spacer()
            quitButtonView
        }
        .frame(width: 300, height: 400)
        .sheet(item: Binding<VideoTrimItem?>(
            get: { 
                viewModel.selectedRecording.map { 
                    VideoTrimItem(url: $0.url, key: UUID()) 
                } 
            },
            set: { newValue in
                viewModel.selectedRecording = newValue != nil ? viewModel.selectedRecording : nil
                if newValue == nil {
                    viewModel.showingTrimmer = false
                }
            }
        )) { item in
            if let selectedRecording = viewModel.selectedRecording {
                viewModel.getVideoTrimmerView(
                    for: selectedRecording,
                    onComplete: { trimmedURL in
                        viewModel.showingTrimmer = false
                        viewModel.selectedRecording = nil
                        // Recordings will refresh automatically via the repository binding
                    },
                    onCancel: {
                        viewModel.showingTrimmer = false
                        viewModel.selectedRecording = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "video.circle")
                .foregroundColor(.blue)
            Text("Kiroku")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Recording Controls View
    private var recordingControlsView: some View {
        VStack(spacing: 12) {
            if !viewModel.hasPermission {
                permissionControlsView
            } else {
                activeRecordingControlsView
                recordingStatusView
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Permission Controls View
    private var permissionControlsView: some View {
        VStack(spacing: 8) {
            Button(action: viewModel.requestPermission) {
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
            
            Button(action: viewModel.checkPermission) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Permission")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Active Recording Controls View
    private var activeRecordingControlsView: some View {
        Button(action: viewModel.exportLastMinute) {
            HStack {
                if viewModel.isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Exporting...")
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text("Save Last 1 Minute")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(viewModel.isExporting)
    }
    
    // MARK: - Recording Status View
    private var recordingStatusView: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                Text("Always Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(viewModel.bufferChunksCount) chunks in buffer")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Recordings List View
    private var recordingsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Past Recordings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewModel.recordings.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if viewModel.recordings.isEmpty {
                emptyRecordingsView
            } else {
                recordingsScrollView
            }
        }
    }
    
    // MARK: - Empty Recordings View
    private var emptyRecordingsView: some View {
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
    }
    
    // MARK: - Recordings Scroll View
    private var recordingsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.recordings, id: \.id) { recording in
                    RecordingRowView(
                        recording: recording,
                        onOpen: { viewModel.openRecording(recording) },
                        onDelete: { viewModel.deleteRecording(recording) },
                        onTrim: { viewModel.showTrimmer(for: recording) },
                        onExportGIF: { viewModel.exportAsGIF(recording) },
                        onCopyToClipboard: { viewModel.copyToClipboard(recording) }
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - Quit Button View
    private var quitButtonView: some View {
        Button("Quit Kiroku") {
            viewModel.quitApp()
        }
        .foregroundColor(.secondary)
        .padding(.bottom)
    }
}

// MARK: - RecordingRowView
struct RecordingRowView: View {
    let recording: Recording
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onTrim: () -> Void
    let onExportGIF: () -> Void
    let onCopyToClipboard: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(recording.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if recording.type == .gif {
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
            
            HStack(spacing: 4) {
                Text(recording.formattedFileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onOpen) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                Menu {
                    if recording.type != .gif {
                        Button(action: onTrim) {
                            Label("Edit", systemImage: "scissors")
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

// MARK: - Preview
#Preview {
    // This won't work without proper DI setup, but kept for Xcode
    Text("Preview requires DI setup")
}
