import AppKit
import VerseglassCore

@MainActor
final class PasteLyricsPanel: NSObject {
    var onSave: ((String) -> Void)?

    private let panel: NSPanel
    private let textView = NSTextView()
    private let errorLabel = NSTextField(labelWithString: "")

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = Copy.pasteLyrics
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.identifier = NSUserInterfaceItemIdentifier("paste-lyrics")
        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        panel.contentView = content

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 64, width: 408, height: 200))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: 408, height: 200)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        content.addSubview(scroll)

        errorLabel.frame = NSRect(x: 16, y: 40, width: 408, height: 18)
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.stringValue = ""
        content.addSubview(errorLabel)

        let cancel = NSButton(title: Copy.cancel, target: self, action: #selector(cancel))
        cancel.frame = NSRect(x: 250, y: 12, width: 84, height: 28)
        cancel.bezelStyle = .rounded
        content.addSubview(cancel)

        let save = NSButton(title: Copy.saveLyrics, target: self, action: #selector(save))
        save.frame = NSRect(x: 340, y: 12, width: 84, height: 28)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        content.addSubview(save)
    }

    func show(existing: String) {
        textView.string = existing
        errorLabel.stringValue = ""
        panel.center()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func cancel() {
        panel.orderOut(nil)
    }

    @objc private func save() {
        let raw = textView.string
        guard !LRCParser.parse(raw).isEmpty else {
            errorLabel.stringValue = Copy.pasteNeedsTime
            return
        }
        panel.orderOut(nil)
        onSave?(raw)
    }
}
