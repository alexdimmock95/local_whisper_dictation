# Local Whisper Dictation for macOS

Source and portable setup templates for a local Whisper dictation utility.

`dictate.sh` records from the microphone on the first run, sends the WAV to a local `whisper-server` on the second run, copies the returned text to the clipboard, and updates the SwiftUI HUD. `WhisperHUD.swift` reads status and transcript files from `~/Library/Caches/WhisperDictation` by default; set `WHISPER_WORKDIR` to override it.

Requirements: macOS, `ffmpeg`, `curl`, `python3`, a compatible `whisper-server` and model, and Swift/Xcode Command Line Tools.

The `launchagents/` templates use placeholders. Replace `__PROJECT_DIR__`, `__MODEL_PATH__`, and `__USER_HOME__`, build/package the HUD executable, create `~/Library/Logs/WhisperDictation`, then copy the configured plists into `~/Library/LaunchAgents/` and load them with `launchctl bootstrap gui/$(id -u) ...`. Configure your shortcut tool to run `dictate.sh`.

Model weights, compiled binaries, app bundles, audio, caches, logs, and transcripts are excluded from Git. These instructions describe a fresh setup and do not alter an existing installation.
