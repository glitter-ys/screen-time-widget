import SwiftUI

enum WidgetLayout {
    static let capsuleWidth: CGFloat = 220
    static let capsuleHeight: CGFloat = 44
    static let drawerWidth: CGFloat = 260
    static let drawerHeight: CGFloat = 244
    static let drawerCornerRadius: CGFloat = 32
    static let gap: CGFloat = 8
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 14
    static let windowWidth = capsuleWidth + horizontalPadding * 2
    static let collapsedHeight = topPadding + capsuleHeight + bottomPadding
    static let expandedHeight = topPadding + capsuleHeight + gap + drawerHeight + bottomPadding
}

struct WidgetActions {
    let togglePause: () -> Void
    let setGoal: (Int) -> Void
    let customGoal: () -> Void
    let setTheme: (WidgetTheme) -> Void
    let hide: () -> Void
    let quit: () -> Void

    static let noop = WidgetActions(
        togglePause: {},
        setGoal: { _ in },
        customGoal: {},
        setTheme: { _ in },
        hide: {},
        quit: {}
    )
}

@MainActor
final class WidgetUIState: ObservableObject {
    @Published var isExpanded = false
    @Published var animatedCompletion = 0
    @Published var animatedCapsuleCompletion = 0
}

struct WidgetChrome: View {
    let metrics: WidgetMetrics
    let expanded: Bool
    let actions: WidgetActions
    @ObservedObject var ui: WidgetUIState

    var body: some View {
        VStack(spacing: WidgetLayout.gap) {
            CapsuleBar(metrics: metrics, action: actions.togglePause, ui: ui)
            if expanded {
                GoalDrawer(metrics: metrics, ui: ui)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: -7))
                                .combined(with: .scale(scale: 0.985, anchor: .top)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        )
                    )
            }
        }
        .padding(.top, WidgetLayout.topPadding)
        .padding(.bottom, expanded ? WidgetLayout.bottomPadding : 0)
        .frame(width: WidgetLayout.windowWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.24), value: expanded)
        .animation(.easeInOut(duration: 0.24), value: metrics.theme)
        .animation(.easeInOut(duration: 0.2), value: metrics.tone)
    }
}

// MARK: - Capsule

private struct CapsuleBar: View {
    let metrics: WidgetMetrics
    let action: () -> Void
    @ObservedObject var ui: WidgetUIState

    var body: some View {
        HStack(spacing: 0) {
            StatusDot(color: metrics.accent)
                .padding(.leading, 15)

            Text(metrics.timeText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(metrics.theme.primaryText)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: metrics.timeText)
                .padding(.leading, 10)
                .lineLimit(1)

            Spacer(minLength: 8)

            Rectangle()
                .fill(metrics.theme.hairline)
                .frame(width: 1, height: 18)
                .padding(.trailing, 7)

            PauseButton(isPaused: metrics.isPaused, action: action, theme: metrics.theme)
                .padding(.trailing, 7)
        }
        .frame(width: WidgetLayout.capsuleWidth, height: WidgetLayout.capsuleHeight)
        .background {
            GlassSurface(
                radius: WidgetLayout.capsuleHeight / 2,
                top: metrics.theme.capsuleTop,
                bottom: metrics.theme.capsuleBottom,
                glow: metrics.accent,
                theme: metrics.theme
            )
        }
        .overlay(alignment: .bottom) {
            CapsuleProgressLine(
                progress: metrics.progress,
                gradient: metrics.accentGradient,
                accent: metrics.accent,
                track: metrics.theme.track,
                completionEvent: metrics.completionEvent,
                ui: ui
            )
            .frame(height: 2)
            .padding(.horizontal, 18)
            .padding(.bottom, 5)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [metrics.theme.borderTop, metrics.theme.borderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .contentShape(Capsule(style: .continuous))
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日屏幕亮屏 \(metrics.timeText)")
        .accessibilityHint("按住胶囊拖动可调整位置")
    }

    private var helpText: String {
        if metrics.statusText.contains("正在读取") { return "正在读取今天的屏幕时间" }
        return "今日亮屏 \(metrics.timeText) · \(metrics.percentText) 目标 · 拖动胶囊可移动位置"
    }
}

private struct CapsuleProgressLine: View {
    let progress: Double
    let gradient: [Color]
    let accent: Color
    let track: Color
    let completionEvent: Int
    @ObservedObject var ui: WidgetUIState
    @State private var glow = false

    var body: some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(track)

                if fraction > 0 {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, proxy.size.width * fraction))
                        .scaleEffect(x: 1, y: glow ? 2.15 : 1, anchor: .center)
                        .shadow(
                            color: accent.opacity(glow ? 0.95 : 0.55),
                            radius: glow ? 5 : 2.5
                        )
                }
            }
        }
        .onAppear { pulseIfNeeded() }
        .onChange(of: completionEvent) { _, _ in pulseIfNeeded() }
        .accessibilityHidden(true)
    }

    private func pulseIfNeeded() {
        guard progress >= 1,
              completionEvent > ui.animatedCapsuleCompletion
        else { return }
        ui.animatedCapsuleCompletion = completionEvent
        withAnimation(.easeOut(duration: 0.18)) {
            glow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.75)) {
                glow = false
            }
        }
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.26))
                .frame(width: 17, height: 17)
                .blur(radius: 5)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .frame(width: 17, height: 17)
        .accessibilityHidden(true)
    }
}

private struct PauseButton: View {
    let isPaused: Bool
    let action: () -> Void
    let theme: WidgetTheme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(theme.primaryText.opacity(hovering ? 1 : 0.82))
                .offset(x: isPaused ? 0.7 : 0)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(hovering ? theme.buttonHover : .clear)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .help(isPaused ? "继续计时" : "暂停计时")
        .accessibilityLabel(isPaused ? "继续计时" : "暂停计时")
    }
}

// MARK: - Drawer

private struct GoalDrawer: View {
    let metrics: WidgetMetrics
    @ObservedObject var ui: WidgetUIState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(metrics.accent)
                    .frame(width: 5, height: 5)
                Text(metrics.heroLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(metrics.theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(height: 14)

            Text(metrics.heroText)
                .font(.system(size: 27, weight: .semibold, design: metrics.theme.heroDesign))
                .monospacedDigit()
                .foregroundStyle(metrics.theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 32, alignment: .leading)
                .padding(.top, 1)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(metrics.progressLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(metrics.theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
                Text(metrics.percentText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(metrics.accent)
            }
            .frame(height: 14)
            .padding(.top, 8)

            GoalProgressBar(metrics: metrics, ui: ui)
                .frame(height: 5)
                .padding(.top, 5)

            EncouragementBanner(encouragement: metrics.encouragement, theme: metrics.theme)
                .padding(.top, 9)

            HStack(spacing: 8) {
                Text(metrics.remainingText)
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(metrics.theme.secondaryText.opacity(0.98))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("目标 \(metrics.goalText)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(metrics.theme.tertiaryText)
                    .lineLimit(1)
            }
            .frame(height: 13)
            .padding(.top, 6)

            Spacer(minLength: 4)

            Rectangle()
                .fill(EncouragementPalette.line(light: metrics.theme.isLight))
                .frame(height: 1)

            HStack(spacing: 6) {
                Circle()
                    .fill(metrics.accent)
                    .frame(width: 6, height: 6)
                Text(metrics.statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(metrics.theme.secondaryText.opacity(0.98))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("右键设置")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(metrics.theme.tertiaryText.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(height: 14)
            .padding(.top, 7)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(width: WidgetLayout.drawerWidth, height: WidgetLayout.drawerHeight, alignment: .topLeading)
        .background {
            GlassSurface(
                radius: WidgetLayout.drawerCornerRadius,
                top: metrics.theme.drawerTop,
                bottom: metrics.theme.drawerBottom,
                glow: metrics.accent,
                theme: metrics.theme
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: WidgetLayout.drawerCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [metrics.theme.borderTop, metrics.theme.borderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metrics.heroLabel) \(metrics.heroText)，\(metrics.percentText)，\(metrics.remainingText)")
    }
}

private struct EncouragementBanner: View {
    let encouragement: Encouragement
    let theme: WidgetTheme

    var body: some View {
        let light = theme.isLight
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: encouragement.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(EncouragementPalette.accent(light: light))
                .frame(width: 18, height: 18, alignment: .center)
                .padding(.top, 1.5)
                .accessibilityHidden(true)

            Text(encouragement.text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(EncouragementPalette.primaryText(light: light))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.encouragementSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    EncouragementPalette.accent(light: light).opacity(light ? 0.18 : 0.26),
                    lineWidth: 0.8
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(encouragement.text)
    }
}

private struct GoalProgressBar: View {
    let metrics: WidgetMetrics
    @ObservedObject var ui: WidgetUIState
    @State private var bump = false
    @State private var shineVisible = false
    @State private var shinePosition: CGFloat = -0.25

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fraction = min(1, max(0, metrics.progress))
            Group {
                if metrics.theme.usesSegmentedProgress {
                    segmentedBar(width: width, fraction: fraction)
                } else if metrics.theme.usesTickProgress {
                    tickBar(width: width, fraction: fraction)
                } else {
                    continuousBar(width: width, fraction: fraction)
                }
            }
            .onAppear { celebrateIfNeeded() }
            .onChange(of: metrics.completionEvent) { _, _ in
                celebrateIfNeeded()
            }
        }
    }

    private func continuousBar(width: CGFloat, fraction: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(EncouragementPalette.line(light: metrics.theme.isLight))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(metrics.theme.innerBorder, lineWidth: 0.5)
                }

            if fraction > 0 {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: metrics.accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(5, width * fraction))
                    .overlay {
                        if shineVisible {
                            GeometryReader { shineProxy in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.62), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: max(24, shineProxy.size.width * 0.34))
                                .offset(x: (shineProxy.size.width + 60) * shinePosition - 30)
                            }
                            .clipShape(Capsule(style: .continuous))
                            .allowsHitTesting(false)
                        }
                    }
                    .scaleEffect(x: 1, y: bump ? 1.55 : 1, anchor: .center)
                    .shadow(
                        color: metrics.accent.opacity(bump ? 0.95 : 0.3),
                        radius: bump ? 8 : 4
                    )
            }
        }
    }

    private func segmentedBar(width: CGFloat, fraction: Double) -> some View {
        let count = 12
        let spacing: CGFloat = 3
        let segmentWidth = max(2, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
        let filled = fraction <= 0 ? 0 : min(count, max(1, Int((fraction * Double(count)).rounded())))
        return HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(EncouragementPalette.line(light: metrics.theme.isLight))
                    .overlay {
                        if index < filled {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: metrics.accentGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(
                                    color: metrics.accent.opacity(bump ? 0.85 : 0.16),
                                    radius: bump ? 5 : 1
                                )
                        }
                    }
                    .frame(width: segmentWidth, height: 5)
            }
        }
        .frame(width: width, height: 5)
        .scaleEffect(x: 1, y: bump ? 1.5 : 1, anchor: .center)
    }

    private func tickBar(width: CGFloat, fraction: Double) -> some View {
        let count = 30
        let tickWidth: CGFloat = 1.5
        let spacing = max(1, (width - tickWidth * CGFloat(count)) / CGFloat(count - 1))
        let filled = fraction <= 0 ? 0 : min(count, max(1, Int((fraction * Double(count)).rounded())))
        return HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.75, style: .continuous)
                    .fill(index < filled ? AnyShapeStyle(
                        LinearGradient(
                            colors: metrics.accentGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) : AnyShapeStyle(EncouragementPalette.line(light: metrics.theme.isLight)))
                    .frame(width: tickWidth, height: 5)
            }
        }
        .frame(width: width, height: 5)
        .scaleEffect(x: 1, y: bump ? 1.5 : 1, anchor: .center)
        .shadow(color: metrics.accent.opacity(bump ? 0.8 : 0.12), radius: bump ? 5 : 1)
    }

    private func celebrateIfNeeded() {
        guard metrics.isComplete,
              metrics.completionEvent > ui.animatedCompletion
        else { return }

        ui.animatedCompletion = metrics.completionEvent
        shineVisible = true
        shinePosition = -0.25
        bump = false
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) {
            bump = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.78)) {
                bump = false
                shinePosition = 1.25
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            shineVisible = false
        }
    }
}

// MARK: - Surface

private struct GlassSurface: View {
    let radius: CGFloat
    let top: Color
    let bottom: Color
    let glow: Color
    let theme: WidgetTheme

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RadialGradient(
                    colors: [glow.opacity(theme.glowOpacity), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 150
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.surfaceHighlight, .clear, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.innerBorder, lineWidth: 0.5)
                    .padding(0.6)
            }
    }
}

// MARK: - Preview data

extension WidgetMetrics {
    static func preview(
        theme: WidgetTheme = .mint,
        seconds: Double = 16_320,
        goalMinutes: Int = 480,
        paused: Bool = false
    ) -> WidgetMetrics {
        let goalSeconds = Double(goalMinutes * 60)
        let progress = seconds / goalSeconds
        let complete = seconds + 0.001 >= goalSeconds
        let percent = complete
            ? Int((progress * 100).rounded(.down))
            : min(99, Int((progress * 100).rounded(.down)))
        let remaining = goalSeconds - seconds
        let tone: StatusTone = paused ? .paused : (complete ? .achieved : .running)
        return WidgetMetrics(
            timeText: WidgetFormat.clock(seconds),
            isPaused: paused,
            screenAwake: true,
            goalMinutes: goalMinutes,
            progress: progress,
            percentText: "\(percent)%",
            heroText: WidgetFormat.chinese(seconds),
            heroLabel: "今日已亮屏",
            progressLabel: "今日进度",
            goalText: WidgetFormat.goalLong(goalMinutes),
            remainingText: remaining > 0.5
                ? "还差 \(WidgetFormat.chinese(remaining))"
                : (remaining >= -0.5
                    ? "已达成目标"
                    : "已超出 \(WidgetFormat.chinese(-remaining))"),
            statusText: paused
                ? "已暂停 · 不计入今日"
                : (complete ? "目标已达成" : "亮屏计时中"),
            tone: tone,
            theme: theme,
            completionEvent: 0,
            encouragement: Encouragement.resolve(
                seconds: seconds,
                goalSeconds: goalSeconds,
                isPaused: paused,
                ready: true
            )
        )
    }

    static let preview = WidgetMetrics.preview()
}
