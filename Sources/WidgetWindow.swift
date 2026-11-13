import AppKit
import QuartzCore
import SwiftUI

struct WidgetView: View {
    @ObservedObject var model: ScreenTimeModel
    @ObservedObject var ui: WidgetUIState
    let actions: WidgetActions

    var body: some View {
        WidgetChrome(metrics: model.metrics, expanded: ui.isExpanded, actions: actions, ui: ui)
    }
}

final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChange: ((Bool) -> Void)?
    var onDragBegan: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?
    private var trackingAreaReference: NSTrackingArea?

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?() ?? super.menu(for: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        // Control-click is a secondary click on macOS; leave it to SwiftUI's
        // context menu instead of starting a window drag.
        if event.modifierFlags.contains(.control) {
            super.mouseDown(with: event)
            return
        }
        guard let window else {
            super.mouseDown(with: event)
            return
        }
        // Keep the pause/play control fully interactive even if SwiftUI routes
        // its click through the hosting view.
        if isPauseButtonLocation(event.locationInWindow, in: window) {
            super.mouseDown(with: event)
            return
        }
        onDragBegan?()
        let selector = NSSelectorFromString("performWindowDragWithEvent:")
        if window.responds(to: selector) {
            window.perform(selector, with: event)
        }
    }

    private func isPauseButtonLocation(_ point: NSPoint, in window: NSWindow) -> Bool {
        let height = window.contentView?.bounds.height ?? window.frame.height
        let capsuleTop = height - WidgetLayout.topPadding
        let capsuleBottom = capsuleTop - WidgetLayout.capsuleHeight
        let capsuleRight = WidgetLayout.horizontalPadding + WidgetLayout.capsuleWidth
        let controlArea = NSRect(
            x: capsuleRight - 43,
            y: capsuleBottom,
            width: 43,
            height: WidgetLayout.capsuleHeight
        )
        return controlArea.contains(point)
    }
}

@MainActor
final class WidgetWindowController: NSObject, NSWindowDelegate, NSPopoverDelegate {
    let model: ScreenTimeModel
    let panel: NSPanel
    let ui = WidgetUIState()

    private let defaults = UserDefaults.standard
    private var hostingView: TrackingHostingView<WidgetView>!
    private var collapseWorkItem: DispatchWorkItem?
    private var saveWorkItem: DispatchWorkItem?
    private var dragPollTimer: Timer?
    private var frameAnimation: Timer?
    private var frameAnimationStart = Date()
    private var frameAnimationFrom = NSRect.zero
    private var frameAnimationTo = NSRect.zero
    private var historyPopover: NSPopover?
    private var screenObserver: NSObjectProtocol?

    private enum PositionKey {
        static let x = "screenTimer.anchorX"
        static let top = "screenTimer.anchorTop"
    }

    init(model: ScreenTimeModel) {
        self.model = model
        self.panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WidgetLayout.windowWidth,
                height: WidgetLayout.collapsedHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        configureContent()
        restorePosition()
        panel.delegate = self

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeHistory()
                self?.ensureVisibleOnScreen()
            }
        }
    }

    deinit {
        dragPollTimer?.invalidate()
        frameAnimation?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        closeHistory()
        collapseWorkItem?.cancel()
        setExpanded(false)
        // Collapse immediately while hidden so the next show never starts from
        // the taller expanded frame.
        applyAnchor(currentAnchor)
        flushPosition()
        panel.orderOut(nil)
    }

    func toggleVisibility() {
        if panel.isVisible { hide() } else { show() }
    }

    func toggleHistory() {
        if historyPopover?.isShown == true {
            closeHistory()
            return
        }
        showHistory()
    }

    func showHistory() {
        closeHistory()
        show()
        setExpanded(false)

        // Let the status/context menu finish closing before the popover opens.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.appearance = NSAppearance(named: self.model.theme.isLight ? .aqua : .darkAqua)
            popover.contentSize = NSSize(width: 380, height: 360)
            popover.delegate = self

            let controller = NSHostingController(
                rootView: HistoryView(model: self.model, onClose: { [weak self] in self?.closeHistory() })
            )
            controller.preferredContentSize = NSSize(width: 380, height: 360)
            popover.contentViewController = controller

            let windowRect = NSRect(
                x: (self.panel.frame.width - WidgetLayout.capsuleWidth) / 2,
                y: self.panel.frame.height - WidgetLayout.topPadding - WidgetLayout.capsuleHeight,
                width: WidgetLayout.capsuleWidth,
                height: WidgetLayout.capsuleHeight
            )
            let viewRect = self.hostingView.convert(windowRect, from: nil)
            self.historyPopover = popover
            popover.show(relativeTo: viewRect, of: self.hostingView, preferredEdge: .minY)
        }
    }

    func closeHistory() {
        historyPopover?.performClose(nil)
        historyPopover = nil
    }

    func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover, popover === historyPopover else { return }
        historyPopover = nil
    }

    /// Diagnostic-only: render the live hosting view to a PNG without needing
    /// Screen Recording permission. Enabled only through an environment variable.
    func capture(to path: String) {
        guard let view = panel.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        let diagnostics = """
        panel.frame=\(panel.frame)
        anchor=\(currentAnchor)
        content.frame=\(view.frame)
        mouse=\(NSEvent.mouseLocation)
        screens=\(NSScreen.screens.map { "\($0.frame) visible=\($0.visibleFrame)" }.joined(separator: " | "))
        """
        try? diagnostics.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
    }

    func debugExpand() {
        show()
        setExpanded(true)
    }

    func captureHistory(to path: String) {
        guard let view = historyPopover?.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Center the capsule at the top of the screen currently under the pointer.
    func recenter() {
        closeHistory()
        guard let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let anchor = CGPoint(
            x: visible.midX - WidgetLayout.windowWidth / 2,
            y: visible.maxY
        )
        applyAnchor(anchor)
        persistAnchor(anchor)
    }

    /// Persist the current position even if the debounce has not fired yet.
    func flushPosition() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        dragPollTimer?.invalidate()
        dragPollTimer = nil
        persistAnchor(currentAnchor)
    }

    // MARK: - Position

    private var currentAnchor: CGPoint {
        CGPoint(x: panel.frame.minX, y: panel.frame.maxY)
    }

    private func restorePosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        if let saved = loadAnchor() {
            let targetScreen = screenContaining(saved) ?? nearestScreen(to: saved) ?? screen
            let clamped = clamp(saved, to: targetScreen)
            applyAnchor(clamped)
            persistAnchor(clamped)
        } else {
            let visible = screen.visibleFrame
            let anchor = CGPoint(x: visible.midX - WidgetLayout.windowWidth / 2, y: visible.maxY)
            applyAnchor(anchor)
            persistAnchor(anchor)
        }
    }

    private func ensureVisibleOnScreen() {
        let anchor = currentAnchor
        guard let screen = screenContaining(anchor) ?? nearestScreen(to: anchor) ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let clamped = clamp(anchor, to: screen)
        if clamped != anchor {
            applyAnchor(clamped)
        }
        persistAnchor(clamped)
    }

    private func finishDrag() {
        let anchor = currentAnchor
        guard let screen = screenContaining(anchor) ?? nearestScreen(to: anchor) ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let clamped = clamp(anchor, to: screen)
        if clamped != anchor {
            applyAnchor(clamped)
        }
        persistAnchor(clamped)
    }

    private func applyAnchor(_ anchor: CGPoint) {
        frameAnimation?.invalidate()
        frameAnimation = nil
        let height = ui.isExpanded ? WidgetLayout.expandedHeight : WidgetLayout.collapsedHeight
        let frame = NSRect(
            x: anchor.x,
            y: anchor.y - height,
            width: WidgetLayout.windowWidth,
            height: height
        )
        panel.setFrame(frame, display: true)
    }

    private func clamp(_ anchor: CGPoint, to screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        let margin: CGFloat = 6
        let width = WidgetLayout.windowWidth
        let height = WidgetLayout.collapsedHeight

        let x: CGFloat
        if visible.width <= width + margin * 2 {
            x = visible.midX - width / 2
        } else {
            x = min(max(anchor.x, visible.minX + margin), visible.maxX - width - margin)
        }

        let top: CGFloat
        if visible.height <= height + margin * 2 {
            top = visible.maxY
        } else {
            top = min(max(anchor.y, visible.minY + height + margin), visible.maxY)
        }
        return CGPoint(x: x, y: top)
    }

    private func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.insetBy(dx: -1, dy: -1).contains(point) }
    }

    private func nearestScreen(to point: CGPoint) -> NSScreen? {
        NSScreen.screens.min { left, right in
            distance(from: point, to: left.visibleFrame) < distance(from: point, to: right.visibleFrame)
        }
    }

    private func distance(from point: CGPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    private func loadAnchor() -> CGPoint? {
        guard
            defaults.object(forKey: PositionKey.x) != nil,
            defaults.object(forKey: PositionKey.top) != nil
        else { return nil }
        let x = defaults.double(forKey: PositionKey.x)
        let top = defaults.double(forKey: PositionKey.top)
        guard x.isFinite, top.isFinite else { return nil }
        return CGPoint(x: x, y: top)
    }

    private func persistAnchor(_ anchor: CGPoint) {
        defaults.set(Double(anchor.x), forKey: PositionKey.x)
        defaults.set(Double(anchor.y), forKey: PositionKey.top)
    }

    private func schedulePositionSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.persistAnchor(self.currentAnchor)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    func windowDidMove(_ notification: Notification) {
        schedulePositionSave()
        if NSEvent.pressedMouseButtons & 0x1 != 0 {
            beginDragTracking()
        }
    }

    private func beginDragTracking() {
        guard dragPollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollDragState() }
        }
        RunLoop.main.add(timer, forMode: .common)
        dragPollTimer = timer
    }

    private func pollDragState() {
        guard NSEvent.pressedMouseButtons & 0x1 == 0 else { return }
        dragPollTimer?.invalidate()
        dragPollTimer = nil
        finishDrag()
    }

    // MARK: - Setup

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.title = "屏幕计时"
    }

    private func configureContent() {
        let actions = WidgetActions(
            togglePause: { [weak self] in self?.model.togglePause() },
            setGoal: { [weak self] minutes in self?.model.setGoal(minutes: minutes) },
            customGoal: { [weak self] in
                self?.setExpanded(false)
                (NSApp.delegate as? AppDelegate)?.promptForCustomGoal()
            },
            setTheme: { [weak self] theme in self?.model.setTheme(theme) },
            hide: { [weak self] in self?.hide() },
            quit: { NSApp.terminate(nil) }
        )

        let root = WidgetView(model: model, ui: ui, actions: actions)
        hostingView = TrackingHostingView(rootView: root)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: WidgetLayout.windowWidth,
            height: WidgetLayout.collapsedHeight
        )
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.onHoverChange = { [weak self] inside in
            guard let self else { return }
            if inside {
                self.collapseWorkItem?.cancel()
                self.collapseWorkItem = nil
                self.setExpanded(true)
            } else {
                self.scheduleCollapse()
            }
        }
        hostingView.onDragBegan = { [weak self] in
            guard let self else { return }
            self.closeHistory()
            self.collapseWorkItem?.cancel()
            self.collapseWorkItem = nil
            self.beginDragTracking()
        }
        hostingView.contextMenuProvider = {
            (NSApp.delegate as? AppDelegate)?.makeContextMenu()
        }
        panel.contentView = hostingView
    }

    // MARK: - Hover

    private func scheduleCollapse() {
        collapseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let pointer = NSEvent.mouseLocation
            if self.panel.frame.insetBy(dx: -3, dy: -3).contains(pointer) { return }
            self.setExpanded(false)
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
    }

    private func setExpanded(_ expanded: Bool) {
        guard ui.isExpanded != expanded, panel.isVisible else { return }
        if expanded {
            closeHistory()
        }
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        withAnimation(.easeOut(duration: 0.24)) {
            ui.isExpanded = expanded
        }

        let height = expanded ? WidgetLayout.expandedHeight : WidgetLayout.collapsedHeight
        let top = panel.frame.maxY
        let frame = NSRect(
            x: panel.frame.minX,
            y: top - height,
            width: WidgetLayout.windowWidth,
            height: height
        )
        animatePanel(to: frame)
    }

    private func animatePanel(to target: NSRect, duration: TimeInterval = 0.24) {
        frameAnimation?.invalidate()
        frameAnimation = nil
        frameAnimationFrom = panel.frame
        frameAnimationTo = target
        frameAnimationStart = Date()

        guard abs(frameAnimationFrom.height - target.height) > 0.5 else {
            panel.setFrame(target, display: true)
            return
        }

        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(stepFrameAnimation(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        frameAnimation = timer
    }

    @objc private func stepFrameAnimation(_ timer: Timer) {
        let duration: TimeInterval = 0.24
        let t = min(1, max(0, Date().timeIntervalSince(frameAnimationStart) / duration))
        let eased = 1 - pow(1 - t, 3)
        let from = frameAnimationFrom
        let to = frameAnimationTo
        let height = from.height + (to.height - from.height) * eased
        let frame = NSRect(
            x: to.minX,
            y: to.maxY - height,
            width: to.width,
            height: height
        )
        panel.setFrame(frame, display: true)

        if t >= 1 {
            timer.invalidate()
            frameAnimation = nil
            panel.setFrame(to, display: true)
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
