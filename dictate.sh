#!/bin/zsh

# Whisper Dictation for macOS
# First shortcut press: start recording; second press: transcribe and copy.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

USER_HOME="${HOME:?HOME must be set}"
WORKDIR="${WHISPER_WORKDIR:-$USER_HOME/Library/Caches/WhisperDictation}"
STATE="$WORKDIR/recording.pid"
STATUS="$WORKDIR/status.txt"
LATEST_TRANSCRIPT="$WORKDIR/latest-transcript.txt"
LOG="$WORKDIR/recording.log"
SERVER="${WHISPER_SERVER:-http://127.0.0.1:8080}"
LANGUAGE="${WHISPER_LANGUAGE:-auto}"

set_status() { printf '%s\n' "$1" > "$STATUS"; }
notify() { echo "$1"; }
mkdir -p "$WORKDIR"

FFMPEG="$(command -v ffmpeg || true)"
CURL="$(command -v curl || true)"
PYTHON="$(command -v python3 || true)"

if [[ -z "$FFMPEG" || -z "$CURL" || -z "$PYTHON" ]]; then
    notify "Missing FFmpeg, curl or Python. Check installation."
    exit 1
fi

if [[ -f "$STATE" ]]; then
    PID="$(sed -n '1p' "$STATE")"
    AUDIO="$(sed -n '2p' "$STATE")"
    if [[ "$PID" == <-> ]] && kill -0 "$PID" 2>/dev/null; then
        notify "Recording stopped. Transcribing..."
        set_status "processing"
        kill -INT "$PID"
        for i in {1..120}; do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.25
        done
        if kill -0 "$PID" 2>/dev/null; then
            kill -TERM "$PID" 2>/dev/null
            sleep 1
        fi
        rm -f "$STATE"
        if [[ ! -s "$AUDIO" ]]; then
            set_status "error"
            notify "No audio recording was created."
            exit 1
        fi

        RESPONSE="${AUDIO%.wav}.json"
        TRANSCRIPT="${AUDIO%.wav}.txt"
        if ! "$CURL" --silent --output /dev/null --connect-timeout 2 "$SERVER/"; then
            set_status "error"
            notify "Whisper server is not running."
            exit 1
        fi
        if "$CURL" --silent --show-error --fail "$SERVER/inference" \
            -F "file=@$AUDIO" -F "response_format=json" \
            -F "language=$LANGUAGE" -o "$RESPONSE" 2>> "$LOG"; then
            if "$PYTHON" -c '
import json
import sys
data = json.load(sys.stdin)
text = data.get("text")
if not isinstance(text, str):
    raise SystemExit("No transcription text found in response.")
sys.stdout.write(text)
' < "$RESPONSE" > "$TRANSCRIPT" 2>> "$LOG"; then
                if [[ -s "$TRANSCRIPT" ]]; then
                    cp "$TRANSCRIPT" "$LATEST_TRANSCRIPT"
                    /usr/bin/pbcopy < "$TRANSCRIPT"
                    # Remove this successful run's temporary artifacts only.
                    rm -f "$AUDIO" "$RESPONSE" "$TRANSCRIPT"
                    set_status "complete"
                    notify "Transcription copied to clipboard!"
                    echo "Whisper Dictation finished successfully."
                    exit 0
                fi
            fi
        fi
        set_status "error"
        notify "Transcription failed. Check the log."
        exit 1
    else
        rm -f "$STATE"
        set_status "error"
        notify "Previous recording state was stale. Try again."
        exit 1
    fi
fi

AUDIO="$WORKDIR/recording-$(date +%Y%m%d-%H%M%S).wav"
"$FFMPEG" -hide_banner -loglevel error -f avfoundation -i ":1" \
    -ac 1 -ar 16000 -c:a pcm_s16le "$AUDIO" \
    > "$LOG" 2>&1 < /dev/null &
PID=$!
sleep 1
if ! kill -0 "$PID" 2>/dev/null; then
    set_status "error"
    notify "Could not access microphone. Check permissions."
    exit 1
fi
printf '%s\n%s\n' "$PID" "$AUDIO" > "$STATE"
set_status "recording"
notify "Recording started. Press shortcut again to finish."
exit 0
