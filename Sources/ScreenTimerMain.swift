import AppKit
import Foundation

@main
struct ScreenTimerMain {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments

        if arguments.contains("--dump") {
            dumpPowerLog()
            return
        }

        if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
            NSApplication.shared.setActivationPolicy(.prohibited)
            SnapshotRenderer.run(directory: arguments[index + 1])
            return
        }

        if let index = arguments.firstIndex(of: "--icon"), index + 1 < arguments.count {
            NSApplication.shared.setActivationPolicy(.prohibited)
            SnapshotRenderer.renderIcon(to: arguments[index + 1])
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    @MainActor
    private static func dumpPowerLog() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "log"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            FileHandle.standardError.write(Data("failed to launch pmset: \(error)\n".utf8))
            exit(1)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
            FileHandle.standardError.write(Data("pmset failed\n".utf8))
            exit(1)
        }

        do {
            let snapshot = try PowerLogReader.parse(text)
            let formatter = ISO8601DateFormatter()
            let payload: [String: Any] = [
                "ok": true,
                "todayOnSeconds": Int(snapshot.todayOn),
                "todayOn": WidgetFormat.clock(snapshot.todayOn),
                "currentlyOn": snapshot.currentlyOn,
                "displayAwake": DisplayState.isAwake,
                "segments": snapshot.segments.count,
                "history": snapshot.history.map { day in
                    [
                        "date": day.dateKey,
                        "seconds": Int(day.onSeconds),
                        "time": WidgetFormat.clock(day.onSeconds),
                    ]
                },
                "firstOn": snapshot.firstOn.map { formatter.string(from: $0) } ?? NSNull(),
                "lastChange": snapshot.lastChange.map { formatter.string(from: $0) } ?? NSNull(),
                "fetchedAt": formatter.string(from: snapshot.fetchedAt),
            ]
            let json = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            print(String(data: json, encoding: .utf8) ?? "{}")
        } catch {
            FileHandle.standardError.write(Data("parse failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
