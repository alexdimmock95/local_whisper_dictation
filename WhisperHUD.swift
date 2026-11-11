
import SwiftUI
import AppKit
import Combine

@main
struct WhisperHUDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        WindowGroup {
            HUDView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowObserver: NSObjectProtocol?
    private var configuredWindows = Set<Int>()

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSApp.setActivationPolicy(.accessory)

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in

            guard let self,
                  let window = notification.object as? NSWindow else {
                return
            }

            // Configure each window only once.
            guard !self.configuredWindows.contains(window.windowNumber) else {
                return
            }

            self.configuredWindows.insert(window.windowNumber)

            window.level = .floating
            window.styleMask.remove(.titled)
            window.styleMask.remove(.fullSizeContentView)
            window.styleMask.insert(.borderless)

            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true

            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary
            ]
        }
    }

    deinit {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
    }
}

struct HUDView: View {

    @State private var status = "ready"
    @State private var lastObservedStatus = "ready"
    @State private var elapsed = 0
    @State private var transcript = ""
    @State private var dismissalSeconds = 0

    private let timer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {

        HStack(spacing: 14) {

            Image(systemName: iconName)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(iconColour)
                .frame(width: 42, height: 42)
                .background(iconColour.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {

                Text(heading)
                    .font(.system(size: 14, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if status == "recording" {
                Text(formattedTime)
                    .font(.system(
                        size: 12,
                        weight: .medium,
                        design: .monospaced
                    ))
                    .foregroundStyle(.secondary)
            }

            if status == "processing" {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.12))
        }
        .onReceive(timer) { _ in
            updateStatus()
        }
        .onAppear {
            readStatus()
            lastObservedStatus = status
        }
    }

    // MARK: - Display properties

    private var heading: String {
        switch status {
        case "recording": return "Listening"
        case "processing": return "Transcribing"
        case "complete": return "Transcription"
        case "error": return "Error"
        default: return "Standby"
        }
    }

    private var subtitle: String {
        switch status {
        case "recording":
            return "Recording your voice..."
        case "processing":
            return "Processing audio..."
        case "complete":
            return transcript.isEmpty ? "Copied to clipboard" : transcript
        case "error":
            return "Something went wrong. Check the log."
        default:
            return "Ready to dictate"
        }
    }

    private var iconName: String {
        switch status {
        case "recording": return "waveform"
        case "processing": return "waveform.circle"
        case "complete": return "checkmark"
        case "error": return "exclamationmark.triangle"
        default: return "mic"
        }
    }

    private var iconColour: Color {
        switch status {
        case "recording": return .red
        case "processing": return .orange
        case "complete": return .green
        case "error": return .red
        default: return .green
        }
    }

    private var formattedTime: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    // MARK: - Status monitoring

    private func updateStatus() {

        readStatus()

        if status != lastObservedStatus {

            lastObservedStatus = status

            switch status {

            case "recording":
                elapsed = 0
                dismissalSeconds = 0
                showHUD()

            case "processing":
                dismissalSeconds = 0
                showHUD()

            case "complete", "error":
                dismissalSeconds = 5
                showHUD()

            case "ready":
                dismissalSeconds = 0
                hideHUD()

            default:
                break
            }
        }

        if status == "recording" {
            elapsed += 1
        }

        if status == "complete" || status == "error" {
            if dismissalSeconds > 0 {
                dismissalSeconds -= 1
            } else {
                hideHUD()
            }
        }
    }

    private func readStatus() {

        let workDirectory = ProcessInfo.processInfo.environment["WHISPER_WORKDIR"]
            ?? (NSHomeDirectory() + "/Library/Caches/WhisperDictation")
        let path = workDirectory + "/status.txt"

        if let contents = try? String(
            contentsOfFile: path,
            encoding: .utf8
        ) {

            let newStatus = contents.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if [
                "ready",
                "recording",
                "processing",
                "complete",
                "error"
            ].contains(newStatus) {
                status = newStatus
            }

        } else {
            status = "ready"
        }

        let transcriptPath = workDirectory + "/latest-transcript.txt"

        if let contents = try? String(
            contentsOfFile: transcriptPath,
            encoding: .utf8
        ) {
            transcript = contents.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
    }

    // MARK: - Window visibility

    private func showHUD() {

        guard let window = NSApp.windows.first else {
            return
        }

        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    private func hideHUD() {

        guard let window = NSApp.windows.first else {
            return
        }

        if window.isVisible {
            window.orderOut(nil)
        }
    }
}
