# Kiroku

A simple macOS menubar app for screen recording.

## Features

- Records screen to .mov files
- Lives in the menubar
- Shows list of past recordings
- Open/delete recordings from the app

## Requirements

- macOS 10.15+
- FFmpeg (install with `brew install ffmpeg`)
- Screen recording permissions

## Setup

1. Clone and build in Xcode
2. Grant screen recording permissions when prompted
3. Install FFmpeg if needed

## Usage

Click the menubar icon to open the app. Press "Start Recording" to begin, "Stop Recording" to end. Recordings are saved to `~/Documents/Kiroku Recordings/`.

## Implementation

Uses FFmpeg with AVFoundation for screen capture. Automatically detects the correct screen device index across different Mac configurations.