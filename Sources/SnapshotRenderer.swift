import AppKit
import SwiftUI

@MainActor
enum SnapshotRenderer {
    static func run(directory: String) {
        let base = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let mint = WidgetMetrics.preview(theme: .mint)
        let sunset = WidgetMetrics.preview(theme: .sunset)
        let berry = WidgetMetrics.preview(theme: .berry)
        let complete = WidgetMetrics.preview(theme: .mint, seconds: 31_080)
        let paused = WidgetMetrics.preview(theme: .mint, paused: true)
        let minimal = WidgetMetrics.preview(theme: .minimal)
        let cream = WidgetMetrics.preview(theme: .cream)
        let amber = WidgetMetrics.preview(theme: .amber)
        let ice = WidgetMetrics.preview(theme: .ice)
        let terracotta = WidgetMetrics.preview(theme: .terracotta)

        write(
            PreviewScene(metrics: mint, expanded: false),
            size: CGSize(width: 900, height: 240),
            to: base.appendingPathComponent("preview-collapsed.png")
        )
        write(
            PreviewScene(metrics: mint, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-expanded.png")
        )
        write(
            PreviewScene(metrics: sunset, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-sunset.png")
        )
        write(
            PreviewScene(metrics: berry, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-berry.png")
        )
        write(
            PreviewScene(metrics: complete, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-complete.png")
        )
        write(
            PreviewScene(metrics: paused, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-paused.png")
        )
        write(
            PreviewScene(metrics: minimal, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-minimal.png")
        )
        write(
            PreviewScene(metrics: cream, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-cream.png")
        )
        write(
            PreviewScene(metrics: amber, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-amber.png")
        )
        write(
            PreviewScene(metrics: ice, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-ice.png")
        )
        write(
            PreviewScene(metrics: terracotta, expanded: true),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-terracotta.png")
        )
        write(
            PreviewChrome(metrics: mint, expanded: false)
                .background(mint.theme.capsuleBottom),
            size: CGSize(width: WidgetLayout.windowWidth, height: WidgetLayout.collapsedHeight),
            to: base.appendingPathComponent("widget-collapsed.png"),
            scale: 3
        )
        write(
            PreviewChrome(metrics: mint, expanded: true)
                .background(mint.theme.capsuleBottom),
            size: CGSize(width: WidgetLayout.windowWidth, height: WidgetLayout.expandedHeight),
            to: base.appendingPathComponent("widget-expanded.png"),
            scale: 3
        )
        write(
            PreviewChrome(metrics: complete, expanded: true)
                .background(complete.theme.capsuleBottom),
            size: CGSize(width: WidgetLayout.windowWidth, height: WidgetLayout.expandedHeight),
            to: base.appendingPathComponent("widget-complete.png"),
            scale: 3
        )
        write(
            ThemeShowcase(),
            size: CGSize(width: 900, height: 880),
            to: base.appendingPathComponent("preview-themes.png")
        )
        write(
            StateShowcase(),
            size: CGSize(width: 900, height: 310),
            to: base.appendingPathComponent("preview-states.png")
        )
        write(
            HistoryPreviewScene(),
            size: CGSize(width: 520, height: 440),
            to: base.appendingPathComponent("preview-history.png")
        )
        write(
            HistoryLightShowcase(),
            size: CGSize(width: 900, height: 440),
            to: base.appendingPathComponent("preview-history-light.png")
        )
        write(
            AppIconArt(),
            size: CGSize(width: 1024, height: 1024),
            to: base.appendingPathComponent("app-icon-1024.png"),
            scale: 1
        )
        print("Snapshots written to \(base.path)")
    }

    static func renderIcon(to path: String) {
        write(
            AppIconArt(),
            size: CGSize(width: 1024, height: 1024),
            to: URL(fileURLWithPath: path),
            scale: 1
        )
        print(path)
    }

    private static func write<V: View>(_ view: V, size: CGSize, to url: URL, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard
            let image = renderer.cgImage,
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("could not render \(url.lastPathComponent)\n".utf8))
            return
        }
        do {
            try data.write(to: url)
            print(url.path)
        } catch {
            FileHandle.standardError.write(Data("could not write \(url.path): \(error)\n".utf8))
        }
    }
}

// MARK: - History preview

private struct HistoryPreviewScene: View {
    var body: some View {
        ZStack {
            DesktopWallpaper()
            HistoryCard(
                days: sampleHistoryDays(),
                goalMinutes: 480,
                theme: .mint,
                accent: Palette.mint,
                isPaused: false,
                phase: .ready,
                onClose: {}
            )
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        }
    }
}

private struct HistoryLightShowcase: View {
    var body: some View {
        ZStack {
            DesktopWallpaper()
            HStack(spacing: 20) {
                HistoryCard(
                    days: sampleHistoryDays(),
                    goalMinutes: 480,
                    theme: .minimal,
                    accent: WidgetTheme.minimal.active,
                    isPaused: false,
                    phase: .ready,
                    onClose: {}
                )
                HistoryCard(
                    days: sampleHistoryDays(),
                    goalMinutes: 480,
                    theme: .cream,
                    accent: WidgetTheme.cream.active,
                    isPaused: false,
                    phase: .ready,
                    onClose: {}
                )
            }
            .padding(.top, 20)
        }
    }
}

private func sampleHistoryDays() -> [PowerDay] {
    let values: [Double] = [
        5 * 3600 + 12 * 60,
        7 * 3600 + 45 * 60,
        3 * 3600 + 20 * 60,
        6 * 3600 + 5 * 60,
        8 * 3600 + 30 * 60,
        4 * 3600 + 10 * 60,
        5 * 3600 + 40 * 60,
    ]
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return values.enumerated().compactMap { index, seconds in
        guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else { return nil }
        return PowerDay(date: date, dateKey: formatter.string(from: date), onSeconds: seconds)
    }
}

// MARK: - Showcases

private struct ThemeShowcase: View {
    var body: some View {
        ZStack {
            DesktopWallpaper()
            VStack(spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    card(.mint)
                    card(.sunset)
                    card(.berry)
                }
                HStack(alignment: .top, spacing: 18) {
                    card(.minimal)
                    card(.cream)
                    card(.amber)
                }
                HStack(alignment: .top, spacing: 18) {
                    card(.ice)
                    card(.terracotta)
                }
            }
            .padding(.top, 28)
        }
    }

    private func card(_ theme: WidgetTheme) -> some View {
        VStack(spacing: 8) {
            PreviewChrome(metrics: .preview(theme: theme), expanded: true)
                .frame(width: WidgetLayout.windowWidth, height: WidgetLayout.expandedHeight)
            ShowcaseLabel(text: theme.name)
        }
    }
}

private struct StateShowcase: View {
    var body: some View {
        ZStack {
            DesktopWallpaper()
            HStack(alignment: .top, spacing: 18) {
                item(metrics: .preview(theme: .mint), label: "计时中")
                item(metrics: .preview(theme: .mint, paused: true), label: "暂停")
                item(metrics: .preview(theme: .mint, seconds: 31_080), label: "达到目标")
            }
            .padding(.top, 28)
        }
    }

    private func item(metrics: WidgetMetrics, label: String) -> some View {
        VStack(spacing: 8) {
            PreviewChrome(metrics: metrics, expanded: true)
                .frame(width: WidgetLayout.windowWidth, height: WidgetLayout.expandedHeight)
            ShowcaseLabel(text: label)
        }
    }
}

private struct ShowcaseLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.62))
            .frame(height: 16)
    }
}

// MARK: - Preview scene

private struct PreviewScene: View {
    let metrics: WidgetMetrics
    let expanded: Bool
    @StateObject private var ui = WidgetUIState()

    var body: some View {
        ZStack(alignment: .top) {
            DesktopWallpaper()
            FakeMenuBar()
            WidgetChrome(metrics: metrics, expanded: expanded, actions: .noop, ui: ui)
                .padding(.top, 30)
        }
    }
}

private struct PreviewChrome: View {
    let metrics: WidgetMetrics
    let expanded: Bool
    @StateObject private var ui = WidgetUIState()

    var body: some View {
        WidgetChrome(metrics: metrics, expanded: expanded, actions: .noop, ui: ui)
    }
}

private struct FakeMenuBar: View {
    var body: some View {
        HStack(spacing: 17) {
            Image(systemName: "apple.logo")
                .font(.system(size: 11, weight: .medium))
            Text("访达")
                .font(.system(size: 11, weight: .semibold))
            Text("文件")
            Text("编辑")
            Text("显示")
            Text("前往")
            Text("窗口")
            Text("帮助")
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 10, weight: .semibold))
            Image(systemName: "battery.100")
                .font(.system(size: 12, weight: .regular))
            Text("11月12日 周三  17:02")
                .monospacedDigit()
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.white.opacity(0.76))
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(.black.opacity(0.28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }
}

private struct DesktopWallpaper: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x080B0F), Color(hex: 0x0D1417), Color(hex: 0x070A0C)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(hex: 0x1A7058).opacity(0.38))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 120)
                    .offset(x: -proxy.size.width * 0.27, y: proxy.size.height * 0.38)

                Circle()
                    .fill(Color(hex: 0x214F89).opacity(0.3))
                    .frame(width: proxy.size.width * 0.65)
                    .blur(radius: 140)
                    .offset(x: proxy.size.width * 0.32, y: proxy.size.height * 0.12)

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: 0x9DE8C5).opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: proxy.size.width * 0.7, height: proxy.size.height * 0.9)
                    .rotationEffect(.degrees(-24))
                    .offset(x: proxy.size.width * 0.08, y: proxy.size.height * 0.3)
                    .blur(radius: 40)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.36)],
                    center: .center,
                    startRadius: 80,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.72
                )
            }
        }
    }
}

// MARK: - Icon

private struct AppIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 190, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x292D33), Color(hex: 0x111316), Color(hex: 0x090A0C)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 860, height: 860)
                .overlay {
                    RoundedRectangle(cornerRadius: 190, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.23), .white.opacity(0.025)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                }
                .shadow(color: .black.opacity(0.5), radius: 34, x: 0, y: 20)

            Circle()
                .fill(Palette.mint.opacity(0.16))
                .frame(width: 520, height: 520)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x1B2B27).opacity(0.75), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 220
                    )
                )
                .frame(width: 430, height: 430)

            Circle()
                .trim(from: 0.055, to: 0.945)
                .stroke(
                    AngularGradient(
                        colors: [Palette.mint, Palette.mintTeal, Palette.mint, Palette.mintDeep, Palette.mint],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 32, lineCap: .round)
                )
                .frame(width: 424, height: 424)
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.mint.opacity(0.5), radius: 18)

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index % 3 == 0 ? 0.3 : 0.13))
                    .frame(width: index % 3 == 0 ? 8 : 5, height: index % 3 == 0 ? 20 : 12)
                    .offset(y: -274)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            ClockHands()
                .stroke(
                    .white.opacity(0.94),
                    style: StrokeStyle(lineWidth: 23, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)

            Circle()
                .fill(Palette.mint)
                .frame(width: 43, height: 43)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.48), lineWidth: 2.5)
                }
                .shadow(color: Palette.mint.opacity(0.7), radius: 15)
        }
        .frame(width: 1024, height: 1024)
    }
}

private struct ClockHands: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        // Minute hand, pointing to 12.
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x, y: center.y - 122))

        // Hour hand, pointing to roughly 4 o'clock.
        let angle = Double.pi * 0.72
        path.move(to: center)
        path.addLine(to: CGPoint(
            x: center.x + sin(angle) * 94,
            y: center.y - cos(angle) * 94
        ))
        return path
    }
}
