import AppKit
import Combine
import Foundation
import SwiftUI

struct PauseInterval: Codable {
    let start: Date
    let end: Date
}

enum TrackingPhase: Equatable {
    case loading
    case ready
    case failed
}

enum StatusTone: Equatable {
    case running
    case paused
    case achieved
    case asleep
    case error
}

enum EncouragementStage: Equatable {
    case notStarted
    case early
    case quarter
    case half
    case threeQuarter
    case complete
    case paused

    var text: String {
        switch self {
        case .notStarted: return "新的一天，准备出发！"
        case .early: return "加油呀，今天已经有进展啦！"
        case .quarter: return "进度在长，你也很棒！"
        case .half: return "一半达成！给自己点个赞。"
        case .threeQuarter: return "走过四分之三，真不错！"
        case .complete: return "今日目标达成！奖励一下自己。"
        case .paused: return "给自己充个电，休息一下！"
        }
    }

    var icon: String {
        switch self {
        case .notStarted, .early, .quarter: return "leaf.fill"
        case .half, .threeQuarter: return "sparkles"
        case .complete: return "checkmark.circle.fill"
        case .paused: return "cup.and.saucer.fill"
        }
    }
}

struct Encouragement: Equatable {
    let stage: EncouragementStage
    let text: String
    let icon: String

    init(stage: EncouragementStage) {
        self.stage = stage
        self.text = stage.text
        self.icon = stage.icon
    }

    static func resolve(seconds: Double, goalSeconds: Double, isPaused: Bool, ready: Bool) -> Encouragement {
        guard ready, goalSeconds > 0 else {
            return Encouragement(stage: isPaused ? .paused : .notStarted)
        }
        let progress = max(0, seconds / goalSeconds)
        if progress >= 1 - 1e-9 {
            return Encouragement(stage: .complete)
        }
        if isPaused {
            return Encouragement(stage: .paused)
        }
        if seconds < 1 {
            return Encouragement(stage: .notStarted)
        }
        if progress < 0.25 {
            return Encouragement(stage: .early)
        }
        if progress < 0.5 {
            return Encouragement(stage: .quarter)
        }
        if progress < 0.75 {
            return Encouragement(stage: .half)
        }
        return Encouragement(stage: .threeQuarter)
    }
}

struct WidgetMetrics {
    let timeText: String
    let isPaused: Bool
    let screenAwake: Bool
    let goalMinutes: Int
    let progress: Double
    let percentText: String
    let heroText: String
    let heroLabel: String
    let progressLabel: String
    let goalText: String
    let remainingText: String
    let statusText: String
    let tone: StatusTone
    let theme: WidgetTheme
    let completionEvent: Int
    let encouragement: Encouragement

    var isComplete: Bool { progress >= 1 - 1e-9 }

    var accent: Color {
        switch tone {
        case .running: return theme.active
        case .paused: return theme.pauseAccent
        case .achieved: return theme.goldAccent
        case .asleep: return theme.dimAccent
        case .error: return theme.errorAccent
        }
    }

    var accentGradient: [Color] {
        switch tone {
        case .running: return theme.gradient
        case .paused: return theme.pauseGradient
        case .achieved: return theme.goldGradient
        case .asleep: return [theme.dimAccent, theme.dimAccent.opacity(0.65)]
        case .error: return [theme.errorAccent, theme.errorAccent.opacity(0.75)]
        }
    }
}

@MainActor
final class ScreenTimeModel: ObservableObject {
    @Published private(set) var phase: TrackingPhase = .loading
    @Published private(set) var displaySeconds: Double = 0
    @Published private(set) var isPaused = false
    @Published private(set) var screenAwake = true
    @Published private(set) var goalMinutes = 480
    @Published private(set) var theme: WidgetTheme = .mint
    @Published private(set) var heroLabel = "今日已亮屏"
    @Published private(set) var progressLabel = "今日进度"
    @Published private(set) var completionEvent = 0
    @Published private(set) var history: [PowerDay] = []
    @Published private(set) var firstOn: Date?
    @Published private(set) var lastChange: Date?
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncError: String?

    private let defaults = UserDefaults.standard
    private let refreshInterval: TimeInterval = 20

    private var tickTimer: Timer?
    private var refreshTimer: Timer?
    private var started = false
    private var refreshing = false
    private var lastTick = Date()
    private var pauseIntervals: [PauseInterval] = []
    private var pausedAt: Date?
    private var frozenSeconds: Double = 0
    private var currentDay = ""
    private var hasLoadedOnce = false
    private var lastReached = false
    private var wakeObservers: [NSObjectProtocol] = []

    private enum Key {
        static let goal = "screenTimer.goalMinutes"
        static let theme = "screenTimer.theme"
        static let heroLabel = "screenTimer.heroLabel"
        static let progressLabel = "screenTimer.progressLabel"
        static let paused = "screenTimer.paused"
        static let pausedAt = "screenTimer.pausedAt"
        static let frozen = "screenTimer.frozenSeconds"
        static let intervals = "screenTimer.pauseIntervals"
    }

    var historyForDisplay: [PowerDay] {
        let todayKey = Self.dayKey(Date())
        return history.map { day in
            guard day.dateKey == todayKey else { return day }
            return PowerDay(date: day.date, dateKey: day.dateKey, onSeconds: displaySeconds)
        }
    }

    var metrics: WidgetMetrics {
        let goalSeconds = Double(max(30, goalMinutes) * 60)
        let progress = goalSeconds > 0 ? max(0, displaySeconds / goalSeconds) : 0
        let ready = phase == .ready
        let complete = ready && goalSeconds > 0 && displaySeconds + 0.001 >= goalSeconds
        // Round down so 99.x% never reads as a finished 100%.
        let rawPercent = Int((progress * 100).rounded(.down))
        let percent = complete ? rawPercent : min(99, rawPercent)
        let reached = complete

        let tone: StatusTone
        let status: String
        if phase == .failed {
            tone = .error
            status = syncError ?? "无法读取屏幕时间"
        } else if phase == .loading {
            tone = .asleep
            status = "正在读取电源日志"
        } else if isPaused {
            tone = .paused
            status = "已暂停 · 不计入今日"
        } else if reached {
            tone = .achieved
            status = "目标已达成"
        } else if !screenAwake {
            tone = .asleep
            status = "屏幕已关闭 · 计时暂停"
        } else {
            tone = .running
            status = "亮屏计时中"
        }

        let remaining = goalSeconds - displaySeconds
        let remainingText: String
        if !ready {
            remainingText = "—"
        } else if remaining > 0.5 {
            remainingText = "还差 \(WidgetFormat.chinese(remaining))"
        } else if remaining >= -0.5 {
            remainingText = "已达成目标"
        } else {
            remainingText = "已超出 \(WidgetFormat.chinese(-remaining))"
        }

        return WidgetMetrics(
            timeText: ready ? WidgetFormat.clock(displaySeconds) : "--h --m",
            isPaused: isPaused,
            screenAwake: screenAwake,
            goalMinutes: goalMinutes,
            progress: progress,
            percentText: ready ? "\(percent)%" : "—",
            heroText: ready ? WidgetFormat.chinese(displaySeconds) : "—",
            heroLabel: heroLabel,
            progressLabel: progressLabel,
            goalText: WidgetFormat.goalLong(goalMinutes),
            remainingText: remainingText,
            statusText: status,
            tone: tone,
            theme: theme,
            completionEvent: completionEvent,
            encouragement: Encouragement.resolve(
                seconds: displaySeconds,
                goalSeconds: goalSeconds,
                isPaused: isPaused,
                ready: ready
            )
        )
    }

    func start() {
        guard !started else { return }
        started = true
        loadPersistedState()
        currentDay = Self.dayKey(Date())
        lastTick = Date()

        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(tick, forMode: .common)
        tickTimer = tick

        let refreshTicker = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(refreshTicker, forMode: .common)
        refreshTimer = refreshTicker

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            let observer = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.screenAwake = DisplayState.isAwake
                    self?.refresh()
                }
            }
            wakeObservers.append(observer)
        }

        screenAwake = DisplayState.isAwake
        refresh()
    }

    func togglePause() {
        if isPaused { resume() } else { pause() }
    }

    func pause() {
        guard !isPaused else { return }
        frozenSeconds = displaySeconds
        pausedAt = Date()
        isPaused = true
        persist()
    }

    func resume() {
        guard isPaused else { return }
        let now = Date()
        if let start = pausedAt, now > start {
            pauseIntervals.append(PauseInterval(start: start, end: now))
        }
        prunePauseIntervals(now: now)
        pausedAt = nil
        isPaused = false
        lastTick = now
        persist()
        refresh()
    }

    func setGoal(minutes: Int) {
        let clamped = min(24 * 60, max(30, minutes))
        goalMinutes = clamped
        defaults.set(clamped, forKey: Key.goal)
        updateCompletionTracking()
    }

    func setTheme(_ theme: WidgetTheme) {
        self.theme = theme
        defaults.set(theme.rawValue, forKey: Key.theme)
    }

    func setLabels(hero: String, progress: String) {
        heroLabel = Self.normalizedLabel(hero, fallback: "今日已亮屏", limit: 16)
        progressLabel = Self.normalizedLabel(progress, fallback: "今日进度", limit: 10)
        defaults.set(heroLabel, forKey: Key.heroLabel)
        defaults.set(progressLabel, forKey: Key.progressLabel)
    }

    func resetLabels() {
        heroLabel = "今日已亮屏"
        progressLabel = "今日进度"
        defaults.set(heroLabel, forKey: Key.heroLabel)
        defaults.set(progressLabel, forKey: Key.progressLabel)
    }

    private static func normalizedLabel(_ raw: String, fallback: String, limit: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        return String(trimmed.prefix(limit))
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        PowerLogReader.shared.read { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.refreshing = false
                self.handle(result)
            }
        }
    }

    // MARK: - Live ticking

    private func tick() {
        let now = Date()
        rolloverIfNeeded(now: now)

        let awake = DisplayState.isAwake
        if awake != screenAwake {
            screenAwake = awake
            if awake { refresh() }
        }

        if phase == .ready, !isPaused, awake {
            let delta = min(2, max(0, now.timeIntervalSince(lastTick)))
            displaySeconds += delta
            updateCompletionTracking()
        }
        lastTick = now
    }

    private func rolloverIfNeeded(now: Date) {
        let key = Self.dayKey(now)
        guard key != currentDay else { return }
        currentDay = key
        pauseIntervals.removeAll()
        pausedAt = isPaused ? now : nil
        frozenSeconds = 0
        displaySeconds = 0
        lastTick = now
        updateCompletionTracking()
        persist()
        refresh()
    }

    // MARK: - Power log

    private func handle(_ result: Result<PowerSnapshot, Error>) {
        switch result {
        case .success(let snapshot):
            let day = Self.dayKey(Date())
            guard Self.dayKey(snapshot.fetchedAt) == day else {
                refresh()
                return
            }

            phase = .ready
            history = snapshot.history
            firstOn = snapshot.firstOn
            lastChange = snapshot.lastChange
            lastSync = snapshot.fetchedAt
            syncError = nil
            screenAwake = DisplayState.isAwake
            lastTick = Date()

            if !isPaused {
                let adjusted = snapshot.todayOn - pauseOverlap(in: snapshot)
                displaySeconds = max(0, adjusted)
            }
            updateCompletionTracking()
        case .failure(let error):
            if phase != .ready {
                phase = .failed
                syncError = error.localizedDescription
            } else {
                syncError = "同步失败，显示上次结果"
            }
        }
    }

    private func updateCompletionTracking() {
        guard phase == .ready else { return }
        let reached = displaySeconds >= Double(goalMinutes * 60)
        if hasLoadedOnce && reached && !lastReached {
            completionEvent += 1
        }
        lastReached = reached
        hasLoadedOnce = true
    }

    private func pauseOverlap(in snapshot: PowerSnapshot) -> TimeInterval {
        var total: TimeInterval = 0
        for interval in pauseIntervals {
            for segment in snapshot.segments {
                total += segment.overlap(from: interval.start, to: interval.end)
            }
        }
        return total
    }

    private func prunePauseIntervals(now: Date) {
        let start = Calendar.current.startOfDay(for: now)
        pauseIntervals = pauseIntervals.filter { $0.end > start }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let now = Date()
        let storedGoal = defaults.integer(forKey: Key.goal)
        goalMinutes = storedGoal >= 30 ? storedGoal : 480

        if let rawTheme = defaults.string(forKey: Key.theme),
           let savedTheme = WidgetTheme(rawValue: rawTheme) {
            theme = savedTheme
        }
        if let saved = defaults.string(forKey: Key.heroLabel) {
            heroLabel = Self.normalizedLabel(saved, fallback: "今日已亮屏", limit: 16)
        }
        if let saved = defaults.string(forKey: Key.progressLabel) {
            progressLabel = Self.normalizedLabel(saved, fallback: "今日进度", limit: 10)
        }

        if let data = defaults.data(forKey: Key.intervals),
           let decoded = try? JSONDecoder().decode([PauseInterval].self, from: data) {
            pauseIntervals = decoded.filter { $0.end > Calendar.current.startOfDay(for: now) }
        }

        let dayStart = Calendar.current.startOfDay(for: now)
        if defaults.bool(forKey: Key.paused), let stamp = defaults.object(forKey: Key.pausedAt) as? Double {
            let savedAt = Date(timeIntervalSince1970: stamp)
            isPaused = true
            if savedAt < dayStart {
                pausedAt = now
                frozenSeconds = 0
            } else {
                pausedAt = savedAt
                frozenSeconds = max(0, defaults.double(forKey: Key.frozen))
            }
            displaySeconds = frozenSeconds
        }
    }

    private func persist() {
        defaults.set(goalMinutes, forKey: Key.goal)
        defaults.set(theme.rawValue, forKey: Key.theme)
        defaults.set(heroLabel, forKey: Key.heroLabel)
        defaults.set(progressLabel, forKey: Key.progressLabel)
        defaults.set(isPaused, forKey: Key.paused)
        if let pausedAt {
            defaults.set(pausedAt.timeIntervalSince1970, forKey: Key.pausedAt)
        } else {
            defaults.removeObject(forKey: Key.pausedAt)
        }
        defaults.set(frozenSeconds, forKey: Key.frozen)
        if let data = try? JSONEncoder().encode(pauseIntervals) {
            defaults.set(data, forKey: Key.intervals)
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
