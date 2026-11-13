import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = ScreenTimeModel()
    private var widget: WidgetWindowController!
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var summaryItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var goalItems: [Int: NSMenuItem] = [:]
    private var themeItems: [WidgetTheme: NSMenuItem] = [:]
    private var visibilityItem: NSMenuItem!
    private var menuIsOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        widget = WidgetWindowController(model: model)
        configureStatusItem()
        widget.show()
        model.start()

        if ProcessInfo.processInfo.environment["SCREEN_TIMER_PAUSE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.model.pause() }
        }

        if ProcessInfo.processInfo.environment["SCREEN_TIMER_HISTORY"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.widget.showHistory() }
        }
        if let path = ProcessInfo.processInfo.environment["SCREEN_TIMER_HISTORY_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { self.widget.captureHistory(to: path) }
        }

        // Development hook used by the build's visual verification. It is inert
        // unless the environment variable is present.
        if let path = ProcessInfo.processInfo.environment["SCREEN_TIMER_SNAPSHOT"] {
            let expanded = ProcessInfo.processInfo.environment["SCREEN_TIMER_EXPANDED"] == "1"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if expanded { self.widget.debugExpand() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.widget.capture(to: path)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        widget?.flushPosition()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        widget.show()
        return true
    }

    // MARK: - Status item

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "屏幕计时")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "屏幕计时"
        }

        statusMenu = buildStatusMenu()
        statusItem.menu = statusMenu
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        summaryItem = NSMenuItem()
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(.separator())

        pauseItem = NSMenuItem(
            title: "暂停计时",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let history = NSMenuItem(
            title: "近 7 天使用情况…",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        history.target = self
        history.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)
        menu.addItem(history)

        let goals = NSMenuItem(title: "今日目标", action: nil, keyEquivalent: "")
        goals.image = NSImage(systemSymbolName: "target", accessibilityDescription: nil)
        let goalMenu = NSMenu()
        goalMenu.autoenablesItems = false
        for hours in [6, 7, 8, 9, 10] {
            let item = NSMenuItem(
                title: "\(hours) 小时",
                action: #selector(setGoalFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = hours
            goalItems[hours] = item
            goalMenu.addItem(item)
        }
        goalMenu.addItem(.separator())
        let custom = NSMenuItem(title: "自定义…", action: #selector(promptForCustomGoal), keyEquivalent: "")
        custom.target = self
        goalMenu.addItem(custom)
        goals.submenu = goalMenu
        menu.addItem(goals)

        let themes = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themes.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        let themeMenu = NSMenu()
        themeMenu.autoenablesItems = false
        for theme in WidgetTheme.allCases {
            let item = NSMenuItem(
                title: theme.name,
                action: #selector(setThemeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = theme.rawValue
            themeItems[theme] = item
            themeMenu.addItem(item)
        }
        themes.submenu = themeMenu
        menu.addItem(themes)

        let copy = NSMenuItem(
            title: "自定义文案…",
            action: #selector(promptForCopyCustomization),
            keyEquivalent: ""
        )
        copy.target = self
        copy.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
        menu.addItem(copy)

        menu.addItem(.separator())

        visibilityItem = NSMenuItem(
            title: "隐藏小组件",
            action: #selector(toggleWidget),
            keyEquivalent: ""
        )
        visibilityItem.target = self
        menu.addItem(visibilityItem)

        let recenter = NSMenuItem(
            title: "重新居中到顶部",
            action: #selector(recenterWidget),
            keyEquivalent: ""
        )
        recenter.target = self
        recenter.image = NSImage(systemSymbolName: "arrow.up.to.line", accessibilityDescription: nil)
        menu.addItem(recenter)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出屏幕计时", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !menuIsOpen else { return }
        refreshStatusMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatusMenu()
        menuIsOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    private func refreshStatusMenu() {
        let title = menuSummaryTitle()
        if summaryItem.attributedTitle?.string != title {
            summaryItem.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        }

        let pauseTitle = model.isPaused ? "继续计时" : "暂停计时"
        if pauseItem.title != pauseTitle {
            pauseItem.title = pauseTitle
            pauseItem.image = NSImage(
                systemSymbolName: model.isPaused ? "play.fill" : "pause.fill",
                accessibilityDescription: nil
            )
        }

        for (hours, item) in goalItems {
            let state: NSControl.StateValue = model.goalMinutes == hours * 60 ? .on : .off
            if item.state != state { item.state = state }
        }
        for (theme, item) in themeItems {
            let state: NSControl.StateValue = model.theme == theme ? .on : .off
            if item.state != state { item.state = state }
        }

        let visibilityTitle = widget.isVisible ? "隐藏小组件" : "显示小组件"
        if visibilityItem.title != visibilityTitle {
            visibilityItem.title = visibilityTitle
            visibilityItem.image = NSImage(
                systemSymbolName: widget.isVisible ? "eye.slash" : "eye",
                accessibilityDescription: nil
            )
        }
    }

    private func menuSummaryTitle() -> String {
        let metrics = model.metrics
        if model.phase == .loading {
            return "正在读取今日屏幕时间…"
        }
        if model.phase == .failed {
            return "屏幕时间暂不可用"
        }
        var title = "今日 \(metrics.timeText) · \(metrics.percentText)"
        if model.isPaused {
            title += " · 已暂停"
        } else if metrics.tone == .achieved {
            title += " · 已达成"
        } else if !model.screenAwake {
            title += " · 屏幕关闭"
        }
        return title
    }

    /// Right-click menu. Built fresh for every open so its checkmarks and
    /// summary always match the model, and no menu items are mutated while a
    /// submenu is tracking.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let summary = NSMenuItem()
        summary.attributedTitle = NSAttributedString(
            string: menuSummaryTitle(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: model.isPaused ? "继续计时" : "暂停计时",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pause.target = self
        pause.image = NSImage(
            systemSymbolName: model.isPaused ? "play.fill" : "pause.fill",
            accessibilityDescription: nil
        )
        menu.addItem(pause)

        let history = NSMenuItem(
            title: "近 7 天使用情况…",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        history.target = self
        history.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)
        menu.addItem(history)

        let goals = NSMenuItem(title: "今日目标", action: nil, keyEquivalent: "")
        goals.image = NSImage(systemSymbolName: "target", accessibilityDescription: nil)
        let goalMenu = NSMenu()
        goalMenu.autoenablesItems = false
        for hours in [6, 7, 8, 9, 10] {
            let item = NSMenuItem(
                title: "\(hours) 小时",
                action: #selector(setGoalFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = hours
            item.state = model.goalMinutes == hours * 60 ? .on : .off
            goalMenu.addItem(item)
        }
        goalMenu.addItem(.separator())
        let custom = NSMenuItem(title: "自定义…", action: #selector(promptForCustomGoal), keyEquivalent: "")
        custom.target = self
        goalMenu.addItem(custom)
        goals.submenu = goalMenu
        menu.addItem(goals)

        let themes = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themes.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        let themeMenu = NSMenu()
        themeMenu.autoenablesItems = false
        for theme in WidgetTheme.allCases {
            let item = NSMenuItem(
                title: theme.name,
                action: #selector(setThemeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = theme.rawValue
            item.state = model.theme == theme ? .on : .off
            themeMenu.addItem(item)
        }
        themes.submenu = themeMenu
        menu.addItem(themes)

        let copy = NSMenuItem(
            title: "自定义文案…",
            action: #selector(promptForCopyCustomization),
            keyEquivalent: ""
        )
        copy.target = self
        copy.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)
        menu.addItem(copy)

        menu.addItem(.separator())
        let recenter = NSMenuItem(
            title: "重新居中到顶部",
            action: #selector(recenterWidget),
            keyEquivalent: ""
        )
        recenter.target = self
        recenter.image = NSImage(systemSymbolName: "arrow.up.to.line", accessibilityDescription: nil)
        menu.addItem(recenter)

        let hide = NSMenuItem(title: "隐藏小组件", action: #selector(toggleWidget), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出屏幕计时", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func togglePause() {
        model.togglePause()
    }

    @objc private func setGoalFromMenu(_ sender: NSMenuItem) {
        model.setGoal(minutes: sender.tag * 60)
    }

    @objc private func showHistory() {
        widget.toggleHistory()
    }

    @objc private func setThemeFromMenu(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let theme = WidgetTheme(rawValue: raw)
        else { return }
        model.setTheme(theme)
    }

    @objc func promptForCopyCustomization() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "自定义卡片文案"
        alert.informativeText = "主标题最多 16 个字，进度标题最多 10 个字；留空会恢复默认。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "恢复默认")

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 76))

        let heroLabel = NSTextField(labelWithString: "主标题")
        heroLabel.frame = NSRect(x: 0, y: 50, width: 58, height: 18)
        heroLabel.font = .systemFont(ofSize: 11, weight: .medium)
        heroLabel.textColor = .secondaryLabelColor

        let heroField = NSTextField(frame: NSRect(x: 66, y: 44, width: 254, height: 24))
        heroField.stringValue = model.heroLabel
        heroField.placeholderString = "今日已亮屏"

        let progressLabel = NSTextField(labelWithString: "进度标题")
        progressLabel.frame = NSRect(x: 0, y: 10, width: 58, height: 18)
        progressLabel.font = .systemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = .secondaryLabelColor

        let progressField = NSTextField(frame: NSRect(x: 66, y: 4, width: 254, height: 24))
        progressField.stringValue = model.progressLabel
        progressField.placeholderString = "今日进度"

        accessory.addSubview(heroLabel)
        accessory.addSubview(heroField)
        accessory.addSubview(progressLabel)
        accessory.addSubview(progressField)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = heroField

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            model.setLabels(hero: heroField.stringValue, progress: progressField.stringValue)
        case .alertThirdButtonReturn:
            model.resetLabels()
        default:
            break
        }
    }

    @objc func promptForCustomGoal() {
        NSApp.activate(ignoringOtherApps: true)
        var initial = String(format: "%.1f", Double(model.goalMinutes) / 60)

        while true {
            let alert = NSAlert()
            alert.messageText = "设置今日目标"
            alert.informativeText = "输入 0.5 到 24 小时之间的目标时长。"
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "取消")

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            field.stringValue = initial
            field.placeholderString = "8"
            field.alignment = .right
            alert.accessoryView = field
            alert.window.initialFirstResponder = field

            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let raw = field.stringValue
                .replacingOccurrences(of: "小时", with: "")
                .replacingOccurrences(of: "h", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let hours = Double(raw), hours >= 0.5, hours <= 24 else {
                initial = field.stringValue
                NSSound.beep()
                continue
            }
            model.setGoal(minutes: Int((hours * 60).rounded()))
            return
        }
    }

    @objc private func toggleWidget() {
        widget.toggleVisibility()
    }

    @objc private func recenterWidget() {
        widget.show()
        widget.recenter()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
