import AppKit
import SwiftUI

enum FloatingWindowInteractionPolicy {
    static func targetCompactState(
        isCompact: Bool,
        pointerIsInside: Bool,
        isPrimaryButtonPressed: Bool
    ) -> Bool {
        guard !isPrimaryButtonPressed else { return isCompact }
        return !pointerIsInside
    }
}

enum FloatingWindowPlacementPolicy {
    static let edgeInset: CGFloat = 18
    static let minimumVisibleSize = CGSize(width: 32, height: 32)

    static func defaultOrigin(visibleFrame: CGRect, windowSize: CGSize) -> CGPoint {
        CGPoint(
            x: visibleFrame.maxX - windowSize.width - edgeInset,
            y: visibleFrame.maxY - windowSize.height - edgeInset
        )
    }

    static func shouldRecover(windowFrame: CGRect, visibleFrames: [CGRect]) -> Bool {
        !visibleFrames.contains { visibleFrame in
            let intersection = windowFrame.intersection(visibleFrame)
            return intersection.width >= minimumVisibleSize.width
                && intersection.height >= minimumVisibleSize.height
        }
    }
}

@MainActor
final class FloatingWindowController: NSObject {
    private let store: QuotaStore
    private let language: LanguageSettings
    private var panel: NSPanel?
    private var compact = true
    private var hoverMonitor: Any?
    private var pointerTimer: Timer?
    private var isTransitioning = false

    init(store: QuotaStore, language: LanguageSettings) {
        self.store = store
        self.language = language
    }

    func show() {
        guard panel == nil else { panel?.orderFrontRegardless(); return }
        let initialSize = compactSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = makeHostingView(compact: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        position(panel, size: initialSize)
        panel.orderFrontRegardless()
        self.panel = panel
        installHoverMonitor()
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluatePointer() }
        }
    }

    func expandAndShow() {
        if panel == nil { show() }
        guard let panel else { return }
        setCompact(false)
        position(panel, size: expandedSize)
        panel.orderFrontRegardless()
    }

    private func rootView() -> some View {
        FloatingQuotaView(store: store, language: language, compact: Binding(
            get: { self.compact },
            set: { self.setCompact($0) }
        ))
    }

    private func setCompact(_ value: Bool) {
        guard compact != value, !isTransitioning, let panel else { return }
        isTransitioning = true
        compact = value
        let oldTopRight = NSPoint(x: panel.frame.maxX, y: panel.frame.maxY)
        let size = value ? compactSize : expandedSize
        let target = NSRect(x: oldTopRight.x - size.width, y: oldTopRight.y - size.height, width: size.width, height: size.height)
        panel.setFrame(target, display: false)
        panel.contentView = makeHostingView(compact: value)
        panel.displayIfNeeded()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isTransitioning = false
            self.evaluatePointer()
        }
    }

    private func makeHostingView(compact: Bool) -> NSView {
        let hosting = NSHostingView(rootView: rootView())
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = !compact
        hosting.layer?.cornerRadius = compact ? 0 : 28
        hosting.layer?.cornerCurve = .continuous
        return hosting
    }

    private var expandedHeight: CGFloat {
        96 + CGFloat(max(store.providers.count, 1)) * 174 + (store.codexResetCredits == nil ? 0 : 28)
    }

    private var compactSize: NSSize {
        let count = max(store.providers.count, 1)
        return NSSize(width: CGFloat(count * 52 + max(count - 1, 0) * 8), height: 56)
    }

    private var expandedSize: NSSize {
        NSSize(width: 356, height: expandedHeight)
    }

    private func position(_ panel: NSPanel, size: NSSize) {
        guard let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        panel.setFrameOrigin(FloatingWindowPlacementPolicy.defaultOrigin(visibleFrame: visible, windowSize: size))
    }

    private func installHoverMonitor() {
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { [weak self] _ in
            Task { @MainActor in self?.evaluatePointer() }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.evaluatePointer()
            return event
        }
    }

    private func evaluatePointer() {
        guard let panel else { return }
        if NSEvent.pressedMouseButtons & 1 == 0,
           FloatingWindowPlacementPolicy.shouldRecover(
               windowFrame: panel.frame,
               visibleFrames: NSScreen.screens.map(\.visibleFrame)
           ) {
            position(panel, size: panel.frame.size)
        }
        if compact { synchronizeCompactSize(panel) }
        let inside = panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation)
        let targetCompact = FloatingWindowInteractionPolicy.targetCompactState(
            isCompact: compact,
            pointerIsInside: inside,
            isPrimaryButtonPressed: NSEvent.pressedMouseButtons & 1 != 0
        )
        setCompact(targetCompact)
    }

    private func synchronizeCompactSize(_ panel: NSPanel) {
        let size = compactSize
        guard abs(panel.frame.width - size.width) > 0.5 || abs(panel.frame.height - size.height) > 0.5 else { return }
        let topRight = NSPoint(x: panel.frame.maxX, y: panel.frame.maxY)
        panel.setFrame(
            NSRect(x: topRight.x - size.width, y: topRight.y - size.height, width: size.width, height: size.height),
            display: true
        )
    }

}
