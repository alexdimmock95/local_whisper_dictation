# Local Whisper Dictation for macOS

A local dictation utility for macOS. Press the configured shortcut once to start recording and again to transcribe, copy the text to the clipboard, and update the SwiftUI HUD.

## Requirements

- macOS
- `ffmpeg`, `curl`, and `python3`
- A compatible local `whisper-server` and model
- Swift and Xcode Command Line Tools

## Setup

The `launchagents/` files are templates. Replace `__PROJECT_DIR__`, `__MODEL_PATH__`, and `__USER_HOME__` with the appropriate paths for your installation. Then build and package the HUD executable, create `~/Library/Logs/WhisperDictation`, copy the configured property lists into `~/Library/LaunchAgents/`, and load them with `launchctl bootstrap gui/$(id -u) ...`. Configure your shortcut tool to run `dictate.sh`.

For a fresh setup, these instructions do not modify an existing installation.

## How it works

On the first shortcut press, [`dictate.sh`](dictate.sh) records microphone audio. On the second press, it sends the WAV file to the local Whisper server, saves the transcript, copies it to the clipboard, and updates the HUD. [`WhisperHUD.swift`](WhisperHUD.swift) reads status and transcript files from `~/Library/Caches/WhisperDictation` by default. Set `WHISPER_WORKDIR` to use a different working directory.

## File handling

Recording and transcription files are stored in the work directory while a dictation is being processed. After a successful transcription, the script copies the text to `latest-transcript.txt` and the clipboard, then deletes that recording's temporary WAV, JSON response, and individual TXT file. The latest transcript is retained and replaced by the next successful dictation.

If recording or transcription fails, that run's files are kept to help diagnose the problem; remove them manually when they are no longer needed. The script also keeps the current status and a diagnostic log, and uses a PID file while recording.

## Git exclusions

Model weights, compiled binaries, app bundles, audio, caches, logs, and transcripts are excluded from Git.
