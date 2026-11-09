import AppKit

struct CardRow {
    var text: String
    var translation: String?
    var isCurrent: Bool
}

@MainActor
final class OverlayPanel {
    private let panel: NSPanel
    private let card = LyricCardView()
    private let defaults: UserDefaults
    private var placed = false

    init(defaults: UserDefaults = .standard, translatorView: NSView) {
        self.defaults = defaults
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.identifier = NSUserInterfaceItemIdentifier("lyric-overlay")
        panel.contentView = card
        card.attach(translatorView)
        card.onMoved = { [weak panel] in
            guard let panel else { return }
            Self.clamp(panel)
        }
        card.onEnded = { [weak self] in
            self?.saveOrigin()
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
    }

    func update(rows: [CardRow], visible: Bool, playing: Bool) {
        if visible {
            let size = card.layout(rows: rows)
            var frame = panel.frame
            let anchor = NSPoint(x: frame.maxX, y: frame.minY)
            frame.size = size
            frame.origin = NSPoint(x: anchor.x - size.width, y: anchor.y)
            if !placed {
                placed = true
                if let origin = savedOrigin() {
                    frame.origin = origin
                } else if let screen = NSScreen.main ?? NSScreen.screens.first {
                    let visibleFrame = screen.visibleFrame
                    frame.origin = NSPoint(
                        x: visibleFrame.maxX - size.width - 40,
                        y: visibleFrame.minY + max(140, visibleFrame.height * 0.22)
                    )
                }
            }
            panel.setFrame(frame, display: true)
            Self.clamp(panel)
        }
        panel.orderFrontRegardless()
        let target: CGFloat = visible ? (playing ? 1 : 0.96) : 0
        guard abs(panel.alphaValue - target) > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = target
        }
    }

    private static func clamp(_ panel: NSPanel) {
        let frame = panel.frame
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        var origin = frame.origin
        origin.x = min(max(origin.x, visible.minX + 12), max(visible.minX, visible.maxX - frame.width - 12))
        origin.y = min(max(origin.y, visible.minY + 12), max(visible.minY, visible.maxY - frame.height - 12))
        panel.setFrameOrigin(origin)
    }

    private func savedOrigin() -> NSPoint? {
        guard let raw = defaults.string(forKey: Self.originKey) else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return NSPoint(x: parts[0], y: parts[1])
    }

    private func saveOrigin() {
        let origin = panel.frame.origin
        defaults.set("\(origin.x),\(origin.y)", forKey: Self.originKey)
    }

    private static let originKey = "cardOrigin"
}

@MainActor
final class LyricCardView: NSView {
    var onMoved: (() -> Void)?
    var onEnded: (() -> Void)?
    private var grab: NSPoint?
    private let body = FlippedBody()
    private var fields: [NSTextField] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.style = .regular
            glass.cornerRadius = 22
            glass.tintColor = NSColor.black.withAlphaComponent(0.46)
            if #available(macOS 27, *) {
                glass.effectIsInteractive = true
            }
            glass.contentView = body
            addSubview(glass)
        } else {
            wantsLayer = true
            layer?.cornerRadius = 22
            layer?.masksToBounds = true
            let effect = NSVisualEffectView(frame: bounds)
            effect.autoresizingMask = [.width, .height]
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            addSubview(effect)
            let shade = NSView(frame: bounds)
            shade.autoresizingMask = [.width, .height]
            shade.wantsLayer = true
            shade.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
            addSubview(shade)
            body.frame = bounds
            body.autoresizingMask = [.width, .height]
            addSubview(body)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func attach(_ view: NSView) {
        view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        view.isHidden = true
        body.addSubview(view)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    func layout(rows: [CardRow]) -> NSSize {
        let maxTextWidth: CGFloat = 460
        let padX: CGFloat = 20
        let padY: CGFloat = 16
        while fields.count < rows.count * 2 {
            let field = NSTextField(wrappingLabelWithString: "")
            field.drawsBackground = false
            field.isBezeled = false
            field.isEditable = false
            field.isSelectable = false
            field.backgroundColor = .clear
            field.textColor = .white
            body.addSubview(field)
            fields.append(field)
        }
        var width: CGFloat = 300
        for (index, row) in rows.enumerated() {
            let main = fields[index * 2]
            let sub = fields[index * 2 + 1]
            let isCurrent = row.isCurrent
            main.isHidden = false
            main.stringValue = row.text
            main.font = .systemFont(ofSize: isCurrent ? 22 : 16, weight: isCurrent ? .semibold : .medium)
            main.textColor = NSColor.white.withAlphaComponent(isCurrent ? 1 : 0.72)
            main.preferredMaxLayoutWidth = maxTextWidth
            width = max(width, min(maxTextWidth, main.intrinsicContentSize.width))
            if let translation = row.translation, !translation.isEmpty {
                sub.isHidden = false
                sub.stringValue = translation
                sub.font = .systemFont(ofSize: isCurrent ? 15 : 13, weight: .regular)
                sub.textColor = NSColor.white.withAlphaComponent(isCurrent ? 0.84 : 0.5)
                sub.preferredMaxLayoutWidth = maxTextWidth
                width = max(width, min(maxTextWidth, sub.intrinsicContentSize.width))
            } else {
                sub.isHidden = true
                sub.stringValue = ""
            }
        }
        let textWidth = width
        var y = padY
        for (index, row) in rows.enumerated() {
            let main = fields[index * 2]
            let sub = fields[index * 2 + 1]
            if index > 0 { y += 14 }
            let mainHeight = main.intrinsicContentSize.height
            main.frame = NSRect(x: padX, y: y, width: textWidth, height: mainHeight)
            y += mainHeight
            if let translation = row.translation, !translation.isEmpty {
                y += 2
                let subHeight = sub.intrinsicContentSize.height
                sub.frame = NSRect(x: padX, y: y, width: textWidth, height: subHeight)
                y += subHeight
            }
        }
        for index in rows.count * 2..<fields.count {
            fields[index].isHidden = true
        }
        let size = NSSize(width: textWidth + padX * 2, height: max(112, y + padY))
        body.frame = NSRect(origin: .zero, size: size)
        return size
    }

    override func mouseDown(with event: NSEvent) {
        grab = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let grab, let window else { return }
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y))
        onMoved?()
    }

    override func mouseUp(with event: NSEvent) {
        grab = nil
        onEnded?()
    }
}

private final class FlippedBody: NSView {
    override var isFlipped: Bool { true }
}
