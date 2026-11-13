import Foundation
import CoreGraphics

struct PowerSegment {
    let start: Date
    let end: Date

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    func overlap(from: Date, to: Date) -> TimeInterval {
        let lower = max(start, from)
        let upper = min(end, to)
        return max(0, upper.timeIntervalSince(lower))
    }
}

struct PowerDay: Identifiable {
    let date: Date
    let dateKey: String
    let onSeconds: TimeInterval

    var id: String { dateKey }
}

struct PowerSnapshot {
    let fetchedAt: Date
    let dayStart: Date
    let todayOn: TimeInterval
    let segments: [PowerSegment]
    let history: [PowerDay]
    let currentlyOn: Bool
    let firstOn: Date?
    let lastChange: Date?
}

enum PowerLogError: LocalizedError {
    case launchFailed(String)
    case unreadable(String)
    case emptyLog

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message): return message
        case .unreadable(let message): return message
        case .emptyLog: return "电源日志为空"
        }
    }
}

enum DisplayState {
    /// True while the main display is powered and awake. A locked screen still
    /// counts as on; display sleep does not.
    static var isAwake: Bool {
        let display = CGMainDisplayID()
        return CGDisplayIsAsleep(display) == 0 && CGDisplayIsActive(display) != 0
    }
}

final class PowerLogReader {
    static let shared = PowerLogReader()

    private let queue = DispatchQueue(label: "screen-timer.power-log", qos: .utility)

    private static let eventExpression = try! NSRegularExpression(
        pattern: #"^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-])(\d{2})(\d{2})\s+Notification\s+Display is turned (on|off)"#
    )

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.isLenient = false
        return formatter
    }()

    func read(completion: @escaping (Result<PowerSnapshot, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let log = try self.runPmset()
                let snapshot = try Self.parse(log)
                completion(.success(snapshot))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func runPmset() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "log"]

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw PowerLogError.launchFailed("无法运行 pmset：\(error.localizedDescription)")
        }

        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 25, execute: timeout)

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()

        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw PowerLogError.unreadable(message?.isEmpty == false ? message! : "pmset 读取失败（\(process.terminationStatus)）")
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw PowerLogError.emptyLog
        }
        return text
    }

    static func parse(_ log: String, now: Date = Date(), calendar: Calendar = .current) throws -> PowerSnapshot {
        struct Event {
            let at: Date
            let on: Bool
        }

        var events: [Event] = []
        log.enumerateLines { line, _ in
            guard line.contains("Display is turned") else { return }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = eventExpression.firstMatch(in: line, range: range) else { return }

            func group(_ index: Int) -> String? {
                guard let range = Range(match.range(at: index), in: line) else { return nil }
                return String(line[range])
            }

            guard
                let date = group(1),
                let time = group(2),
                let sign = group(3),
                let hourOffset = group(4),
                let minuteOffset = group(5),
                let action = group(6),
                let at = stampFormatter.date(from: "\(date) \(time) \(sign)\(hourOffset)\(minuteOffset)")
            else { return }

            events.append(Event(at: at, on: action == "on"))
        }

        guard !events.isEmpty else { throw PowerLogError.emptyLog }
        events.sort { $0.at < $1.at }

        // pmset repeats the same notification from several power sources.
        var deduped: [Event] = []
        for event in events {
            if let previous = deduped.last, previous.on == event.on { continue }
            deduped.append(event)
        }

        var segments: [PowerSegment] = []
        var openStart: Date?
        for event in deduped {
            if event.on {
                if openStart == nil { openStart = event.at }
            } else if let start = openStart {
                if event.at > start { segments.append(PowerSegment(start: start, end: event.at)) }
                openStart = nil
            }
        }
        if let start = openStart, now > start {
            segments.append(PowerSegment(start: start, end: now))
        }

        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        var todaySegments: [PowerSegment] = []
        var todayOn: TimeInterval = 0
        for segment in segments {
            let start = max(segment.start, dayStart)
            let end = min(segment.end, min(now, dayEnd))
            guard end > start else { continue }
            let clipped = PowerSegment(start: start, end: end)
            todaySegments.append(clipped)
            todayOn += clipped.duration
        }

        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.calendar = calendar
        keyFormatter.timeZone = calendar.timeZone
        keyFormatter.dateFormat = "yyyy-MM-dd"

        var history: [PowerDay] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard
                let start = calendar.date(byAdding: .day, value: -offset, to: dayStart),
                let end = calendar.date(byAdding: .day, value: 1, to: start)
            else { continue }
            var total: TimeInterval = 0
            for segment in segments {
                total += segment.overlap(from: start, to: min(end, now))
            }
            history.append(
                PowerDay(
                    date: start,
                    dateKey: keyFormatter.string(from: start),
                    onSeconds: total
                )
            )
        }

        return PowerSnapshot(
            fetchedAt: now,
            dayStart: dayStart,
            todayOn: todayOn,
            segments: todaySegments,
            history: history,
            currentlyOn: openStart != nil,
            firstOn: todaySegments.first?.start,
            lastChange: deduped.last?.at
        )
    }
}
