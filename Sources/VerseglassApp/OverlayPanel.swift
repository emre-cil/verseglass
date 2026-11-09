import AppKit
import VerseglassCore

struct CardRow {
    var text: String
    var translation: String?
    var isCurrent: Bool
    /// Letters already sung. Nil keeps the whole line one color.
    var sungCount: Int?
}

@MainActor
final class OverlayPanel {
    static let minWidth: CGFloat = 320
    static let maxWidth: CGFloat = 720
    static let defaultWidth: CGFloat = 480
    static let widthStep: CGFloat = 40

    var onNudge: ((Int) -> Void)?
    var onResetOffset: (() -> Void)?
    var onHide: (() -> Void)?

    private let panel: NSPanel
    private let card = LyricCardView()
    private let defaults: UserDefaults
    private var placed = false
    private var dragging = false
    private var cardWidth: CGFloat

    var widthPoints: Int { Int(cardWidth.rounded()) }
    var canNarrow: Bool { cardWidth > Self.minWidth + 0.5 }
    var canWiden: Bool { cardWidth < Self.maxWidth - 0.5 }

    init(defaults: UserDefaults = .standard, translatorView: NSView) {
        self.defaults = defaults
        if defaults.object(forKey: Self.widthKey) != nil {
            cardWidth = Self.clampWidth(defaults.double(forKey: Self.widthKey))
        } else {
            cardWidth = Self.defaultWidth
        }
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: cardWidth, height: 180),
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
        panel.isMovableByWindowBackground = false
        panel.identifier = NSUserInterfaceItemIdentifier("lyric-overlay")
        panel.contentView = card
        card.attach(translatorView)
        card.onNudge = { [weak self] steps in self?.onNudge?(steps) }
        card.onResetOffset = { [weak self] in self?.onResetOffset?() }
        card.onHide = { [weak self] in self?.onHide?() }
        card.onMoved = { [weak panel] in
            guard let panel else { return }
            Self.clamp(panel)
        }
        card.onDragging = { [weak self] dragging in
            self?.dragging = dragging
        }
        card.onEnded = { [weak self] in
            self?.saveOrigin()
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
    }

    func adjustWidth(steps: Int) {
        cardWidth = Self.clampWidth(cardWidth + CGFloat(steps) * Self.widthStep)
        defaults.set(Double(cardWidth), forKey: Self.widthKey)
    }

    func resetWidth() {
        cardWidth = Self.defaultWidth
        defaults.set(Double(cardWidth), forKey: Self.widthKey)
    }

    func update(
        rows: [CardRow],
        visible: Bool,
        playing: Bool,
        offsetLabel: String,
        canNudge: Bool,
        fontSize: CGFloat,
        centered: Bool,
        opacity: CGFloat
    ) {
        let hovering = panel.frame.contains(NSEvent.mouseLocation)
        let interactive = visible && (dragging || hovering)
        panel.ignoresMouseEvents = !interactive
        if visible {
            let size = card.layout(
                rows: rows,
                width: cardWidth,
                offsetLabel: offsetLabel,
                canNudge: canNudge,
                fontSize: fontSize,
                centered: centered,
                chromeVisible: interactive
            )
            var frame = panel.frame
            if dragging {
                frame.size = size
            } else {
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
            }
            if panel.frame != frame {
                panel.setFrame(frame, display: true)
            }
            if !dragging {
                Self.clamp(panel)
                saveOrigin()
            }
        }
        panel.orderFrontRegardless()
        let strength = min(1, max(0.4, opacity))
        let target: CGFloat = visible ? strength * (playing ? 1 : 0.96) : 0
        guard abs(panel.alphaValue - target) > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = target
        }
    }

    private static func clampWidth(_ value: CGFloat) -> CGFloat {
        min(maxWidth, max(minWidth, value.rounded()))
    }

    private static func clamp(_ panel: NSPanel) {
        let frame = panel.frame
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        var origin = frame.origin
        origin.x = min(max(origin.x, visible.minX + 12), max(visible.minX, visible.maxX - frame.width - 12))
        origin.y = min(max(origin.y, visible.minY + 12), max(visible.minY, visible.maxY - frame.height - 12))
        if origin != frame.origin {
            panel.setFrameOrigin(origin)
        }
    }

    private func savedOrigin() -> NSPoint? {
        guard let raw = defaults.string(forKey: Self.originKey) else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return NSPoint(x: parts[0], y: parts[1])
    }

    private func saveOrigin() {
        let origin = panel.frame.origin
        if let savedPoint, abs(savedPoint.x - origin.x) < 0.5, abs(savedPoint.y - origin.y) < 0.5 {
            return
        }
        savedPoint = origin
        defaults.set("\(origin.x),\(origin.y)", forKey: Self.originKey)
    }

    private var savedPoint: NSPoint?

    private static let originKey = "cardOrigin"
    private static let widthKey = "cardWidth"
}

@MainActor
final class LyricCardView: NSView {
    var onMoved: (() -> Void)?
    var onEnded: (() -> Void)?
    var onDragging: ((Bool) -> Void)?
    var onNudge: ((Int) -> Void)?
    var onResetOffset: (() -> Void)?
    var onHide: (() -> Void)?

    private var drag: (origin: NSPoint, mouse: NSPoint)?
    private let body = FlippedBody()
    private var fields: [NSTextField] = []
    private let backButton = CardButton(symbol: "minus")
    private let resetButton = CardButton(title: "0")
    private let forwardButton = CardButton(symbol: "plus")
    private let hideButton = CardButton(symbol: "eye.slash")
    private var chrome: [CardButton] { [backButton, resetButton, forwardButton, hideButton] }

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
        backButton.toolTip = Copy.back
        backButton.setAccessibilityLabel(Copy.back)
        backButton.onClick = { [weak self] in self?.onNudge?(-1) }
        resetButton.toolTip = Copy.resetOffset
        resetButton.setAccessibilityLabel(Copy.resetOffset)
        resetButton.onClick = { [weak self] in self?.onResetOffset?() }
        forwardButton.toolTip = Copy.forward
        forwardButton.setAccessibilityLabel(Copy.forward)
        forwardButton.onClick = { [weak self] in self?.onNudge?(1) }
        hideButton.toolTip = Copy.hide
        hideButton.setAccessibilityLabel(Copy.hide)
        hideButton.onClick = { [weak self] in self?.onHide?() }
        for button in chrome {
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func attach(_ view: NSView) {
        view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        view.isHidden = true
        body.addSubview(view)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        for button in chrome where !button.isHidden {
            let local = convert(point, to: button)
            if button.bounds.contains(local) { return button }
        }
        return self
    }

    private static func lineHeight(_ string: String, font: NSFont, width: CGFloat) -> CGFloat {
        let text = NSAttributedString(string: string, attributes: [.font: font])
        let rect = text.boundingRect(
            with: NSSize(width: width, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height) + 2
    }

    func layout(
        rows: [CardRow],
        width: CGFloat,
        offsetLabel: String,
        canNudge: Bool,
        fontSize: CGFloat,
        centered: Bool,
        chromeVisible: Bool
    ) -> NSSize {
        let padX: CGFloat = 22
        let padY: CGFloat = 18
        let textWidth = max(40, width - padX * 2)
        let controlHeight: CGFloat = 32
        let controlGap: CGFloat = 14
        let style = paragraph(centered: centered)
        while fields.count < rows.count * 2 {
            let field = NSTextField(wrappingLabelWithString: "")
            field.translatesAutoresizingMaskIntoConstraints = true
            field.drawsBackground = false
            field.isBezeled = false
            field.isEditable = false
            field.isSelectable = false
            field.backgroundColor = .clear
            field.textColor = .white
            field.lineBreakMode = .byWordWrapping
            field.maximumNumberOfLines = 0
            body.addSubview(field)
            fields.append(field)
        }
        var fonts: [(main: NSFont, sub: NSFont?)] = []
        for (index, row) in rows.enumerated() {
            let main = fields[index * 2]
            let sub = fields[index * 2 + 1]
            let isCurrent = row.isCurrent
            let mainFont = NSFont.systemFont(
                ofSize: isCurrent ? fontSize : max(12, fontSize * 16 / 22),
                weight: isCurrent ? .semibold : .medium
            )
            main.isHidden = false
            main.font = mainFont
            main.attributedStringValue = lyricText(row, font: mainFont, style: style)
            main.preferredMaxLayoutWidth = textWidth
            var subFont: NSFont?
            if let translation = row.translation, !translation.isEmpty {
                let font = NSFont.systemFont(
                    ofSize: max(11, fontSize * (isCurrent ? 15 : 13) / 22),
                    weight: .regular
                )
                subFont = font
                sub.isHidden = false
                sub.font = font
                sub.attributedStringValue = NSAttributedString(string: translation, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.white.withAlphaComponent(isCurrent ? 0.84 : 0.5),
                    .paragraphStyle: style,
                ])
                sub.preferredMaxLayoutWidth = textWidth
            } else {
                sub.isHidden = true
                sub.stringValue = ""
            }
            fonts.append((mainFont, subFont))
        }
        var y = padY
        for (index, row) in rows.enumerated() {
            let main = fields[index * 2]
            let sub = fields[index * 2 + 1]
            if index > 0 { y += 14 }
            let mainHeight = Self.lineHeight(row.text, font: fonts[index].main, width: textWidth)
            main.frame = NSRect(x: padX, y: y, width: textWidth, height: mainHeight)
            y += mainHeight
            if let translation = row.translation, !translation.isEmpty, let font = fonts[index].sub {
                y += 2
                let subHeight = Self.lineHeight(translation, font: font, width: textWidth)
                sub.frame = NSRect(x: padX, y: y, width: textWidth, height: subHeight)
                y += subHeight
            }
        }
        for index in rows.count * 2..<fields.count {
            fields[index].isHidden = true
        }
        let tail: CGFloat = chromeVisible ? controlGap + controlHeight + 14 : padY
        let size = NSSize(width: width, height: max(chromeVisible ? 136 : 72, y + tail))
        body.frame = NSRect(origin: .zero, size: size)
        placeChrome(width: width, label: offsetLabel, canNudge: canNudge, visible: chromeVisible)
        return size
    }

    private func paragraph(centered: Bool) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = centered ? .center : .left
        return style
    }

    private func lyricText(_ row: CardRow, font: NSFont, style: NSParagraphStyle) -> NSAttributedString {
        guard row.isCurrent, let sungCount = row.sungCount else {
            return NSAttributedString(string: row.text, attributes: [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(row.isCurrent ? 1 : 0.72),
                .paragraphStyle: style,
            ])
        }
        let characters = Array(row.text)
        let sung = String(characters.prefix(sungCount))
        let rest = String(characters.dropFirst(sungCount))
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: sung, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: style,
        ]))
        text.append(NSAttributedString(string: rest, attributes: [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.4),
            .paragraphStyle: style,
        ]))
        return text
    }

    private func placeChrome(width: CGFloat, label: String, canNudge: Bool, visible: Bool) {
        let side: CGFloat = 32
        let y: CGFloat = 14
        let inset: CGFloat = 24
        backButton.frame = NSRect(x: inset, y: y, width: side, height: side)
        resetButton.frame = NSRect(x: inset + side + 6, y: y, width: 84, height: side)
        forwardButton.frame = NSRect(x: inset + side + 6 + 84 + 6, y: y, width: side, height: side)
        hideButton.frame = NSRect(x: width - inset - side, y: y, width: side, height: side)
        backButton.isEnabled = canNudge
        forwardButton.isEnabled = canNudge
        resetButton.isEnabled = canNudge
        resetButton.setTitleText(label)
        for button in chrome {
            button.isHidden = !visible
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        drag = (window.frame.origin, screenPoint(of: event, in: window))
        onDragging?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag, let window else { return }
        let mouse = screenPoint(of: event, in: window)
        let proposed = NSPoint(
            x: drag.origin.x + mouse.x - drag.mouse.x,
            y: drag.origin.y + mouse.y - drag.mouse.y
        )
        window.setFrameOrigin(proposed)
        onMoved?()
        let actual = window.frame.origin
        if abs(actual.x - proposed.x) > 0.5 || abs(actual.y - proposed.y) > 0.5 {
            self.drag = (actual, mouse)
        }
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        onDragging?(false)
        onEnded?()
    }

    private func screenPoint(of event: NSEvent, in window: NSWindow) -> NSPoint {
        window.convertPoint(toScreen: event.locationInWindow)
    }
}

private final class FlippedBody: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class CardButton: NSButton {
    var onClick: (() -> Void)?
    private var pressed = false

    init(symbol: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        bezelStyle = .inline
        isBordered = false
        imagePosition = .imageOnly
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            image.isTemplate = true
            self.image = image.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        }
        contentTintColor = .white
        common()
    }

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 84, height: 32))
        bezelStyle = .inline
        isBordered = false
        imagePosition = .noImage
        setTitleText(title)
        common()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setTitleText(_ text: String) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(isEnabled ? 0.95 : 0.35),
            .paragraphStyle: style,
        ])
    }

    override var isEnabled: Bool {
        didSet { updateChrome() }
    }

    private func common() {
        wantsLayer = true
        layer?.cornerRadius = 9
        focusRingType = .none
        refusesFirstResponder = true
        updateChrome()
    }

    private func updateChrome() {
        let alpha: CGFloat
        if !isEnabled {
            alpha = 0.08
        } else if pressed {
            alpha = 0.28
        } else {
            alpha = 0.14
        }
        layer?.backgroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
        contentTintColor = NSColor.white.withAlphaComponent(isEnabled ? 1 : 0.35)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        pressed = true
        updateChrome()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let local = convert(event.locationInWindow, from: nil)
        pressed = bounds.contains(local)
        updateChrome()
    }

    override func mouseUp(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(local)
        pressed = false
        updateChrome()
        guard isEnabled, inside else { return }
        onClick?()
    }
}
