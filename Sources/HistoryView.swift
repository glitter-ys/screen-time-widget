import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: ScreenTimeModel
    let onClose: () -> Void

    var body: some View {
        HistoryCard(
            days: model.historyForDisplay,
            goalMinutes: model.goalMinutes,
            theme: model.theme,
            accent: model.metrics.accent,
            isPaused: model.isPaused,
            phase: model.phase,
            onClose: onClose
        )
    }
}

struct HistoryCard: View {
    let days: [PowerDay]
    let goalMinutes: Int
    let theme: WidgetTheme
    let accent: Color
    let isPaused: Bool
    let phase: TrackingPhase
    let onClose: () -> Void

    @State private var closeHovering = false

    private var totalSeconds: Double {
        days.reduce(0) { $0 + $1.onSeconds }
    }

    private var averageSeconds: Double {
        days.isEmpty ? 0 : totalSeconds / Double(days.count)
    }

    private var scaleMax: Double {
        let longest = days.map(\.onSeconds).max() ?? 0
        return max(longest * 1.14, 3600)
    }

    private var ready: Bool {
        !days.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            summary.padding(.top, 12)
            chart.padding(.top, 14)
            Spacer(minLength: 8)
            footer
        }
        .padding(18)
        .frame(width: 380, height: 360, alignment: .topLeading)
        .background {
            ZStack {
                theme.drawerBottom
                LinearGradient(
                    colors: [theme.drawerTop.opacity(0.94), theme.drawerBottom.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [accent.opacity(0.11), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 230
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.borderTop.opacity(0.85), lineWidth: 0.8)
        }
        .preferredColorScheme(theme.isLight ? .light : .dark)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                    Text("近 7 天")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Text("屏幕亮屏时间 · 含今天")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(theme.primaryText.opacity(closeHovering ? 1 : 0.62))
                    .frame(width: 22, height: 22)
                    .background {
                        Circle()
                            .fill(closeHovering ? theme.buttonHover : .clear)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { closeHovering = $0 }
            .help("关闭")
            .accessibilityLabel("关闭近 7 天使用情况")
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("总计")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.tertiaryText)
                Text(ready ? WidgetFormat.clock(totalSeconds) : "—")
                    .font(.system(size: 23, weight: .semibold, design: theme.heroDesign))
                    .monospacedDigit()
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("日均")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.tertiaryText)
                Text(ready ? WidgetFormat.clock(averageSeconds) : "—")
                    .font(.system(size: 12.5, weight: .semibold, design: theme.heroDesign))
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var chart: some View {
        Group {
            if ready {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(days) { day in
                        dayColumn(day)
                    }
                }
            } else {
                VStack(spacing: 7) {
                    Image(systemName: phase == .failed ? "exclamationmark.triangle" : "clock")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(theme.tertiaryText)
                    Text(phase == .failed ? "暂时无法读取电源日志" : "正在读取近 7 天数据…")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 178)
    }

    private func dayColumn(_ day: PowerDay) -> some View {
        let today = Calendar.current.isDateInToday(day.date)
        let ratio = min(1, max(0, day.onSeconds / scaleMax))
        let fillColors = today
            ? [accent, accent.opacity(0.72)]
            : [theme.active.opacity(0.62), theme.deep.opacity(0.5)]

        return VStack(spacing: 4) {
            Text(compactTime(day.onSeconds))
                .font(.system(size: 9.5, weight: today ? .semibold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(today ? accent : theme.secondaryText.opacity(day.onSeconds > 0 ? 0.9 : 0.42))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 12)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.track)
                    .frame(width: 26, height: 126)

                if ratio > 0 {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: fillColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 26, height: max(4, 126 * ratio))
                        .shadow(color: (today ? accent : theme.active).opacity(today ? 0.4 : 0.18), radius: 4)
                }
            }
            .frame(height: 126)

            Text(today ? "今天" : weekday(day.date))
                .font(.system(size: 10, weight: today ? .semibold : .medium))
                .foregroundStyle(today ? accent : theme.secondaryText)
                .lineLimit(1)

            Text(dateLabel(day.date))
                .font(.system(size: 8.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(theme.tertiaryText.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 4, height: 4)
            Text(footerText)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(theme.secondaryText.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 0)
            if isPaused {
                Text("今日暂停中")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.pauseAccent)
            } else {
                Text("目标 \(WidgetFormat.goalLong(goalMinutes))")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.tertiaryText)
            }
        }
    }

    private var footerText: String {
        if phase == .failed { return "电源日志暂时不可用" }
        return "数据来自 macOS 电源日志 · 历史为亮屏时长"
    }

    private func compactTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds / 60))
        let hours = total / 60
        let minutes = total % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))"
        }
        return "\(minutes)m"
    }

    private func weekday(_ date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let index = Calendar.current.component(.weekday, from: date) - 1
        return names[max(0, min(6, index))]
    }

    private func dateLabel(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%02d/%02d", parts.month ?? 1, parts.day ?? 1)
    }
}
