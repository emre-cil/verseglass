import AppKit
import SwiftUI
import Translation

/// On-device translations into the Mac's preferred language. Apple's Translation
/// framework is free and stays on the machine. Missing language data leaves the
/// original line alone.
@MainActor
final class LyricTranslator {
    private let box = TranslatorBox()
    private let host: NSHostingView<TranslatorView>

    init() {
        host = NSHostingView(rootView: TranslatorView(box: box))
        host.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        host.isHidden = true
    }

    var view: NSView { host }

    func update(lines: [String]) {
        var seen = Set<String>()
        var unique: [String] = []
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, seen.insert(text).inserted else { continue }
            unique.append(text)
        }
        box.replaceLines(unique)
    }

    func translation(for line: String) -> String? {
        guard let value = box.translation(for: line) else { return nil }
        if value.compare(line, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return nil
        }
        return value
    }

    var needsInstall: Bool { box.needsInstall }

    var targetLanguageName: String {
        let identifier = Locale.current.language.minimalIdentifier
        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    func requestInstall() {
        box.requestInstall()
    }
}

private final class TranslatorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    private var generation = 0
    private var results: [String: String] = [:]
    private var availabilityKnown = false
    private var installed = false
    private var installRequested = false

    func replaceLines(_ unique: [String]) {
        lock.lock()
        defer { lock.unlock() }
        guard unique != lines else { return }
        lines = unique
        results = [:]
        generation += 1
    }

    func snapshot() -> (lines: [String], generation: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (lines, generation)
    }

    func translation(for line: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return results[line]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func store(_ map: [String: String]) {
        lock.lock()
        results = map
        lock.unlock()
    }

    func setAvailability(installed: Bool, prompt: Bool) {
        lock.lock()
        availabilityKnown = true
        self.installed = installed
        if !prompt {
            installRequested = installRequested && !installed
        }
        promptInstall = prompt
        lock.unlock()
    }

    private var promptInstall = false

    func requestInstall() {
        lock.lock()
        installRequested = true
        lock.unlock()
    }

    var needsInstall: Bool {
        lock.lock()
        defer { lock.unlock() }
        return availabilityKnown && promptInstall && !installed && !installRequested
    }

    func allowsTranslation() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return installed || installRequested
    }

    func makeAction() -> (TranslationSession) async -> Void {
        { session in
            let lines = self.snapshot().lines
            guard !lines.isEmpty else { return }
            self.store(await LyricTranslationBatch.run(session, lines: lines))
        }
    }
}

private enum LyricTranslationBatch {
    static func run(_ session: TranslationSession, lines: [String]) async -> [String: String] {
        var map: [String: String] = [:]
        for line in lines {
            guard let response = try? await session.translate(line) else { continue }
            map[line] = response.targetText
        }
        return map
    }
}

private struct TranslatorView: View {
    let box: TranslatorBox
    let action: (TranslationSession) async -> Void
    @State private var configuration: TranslationSession.Configuration?

    init(box: TranslatorBox) {
        self.box = box
        action = box.makeAction()
    }

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration, action: action)
            .task {
                let target = Locale.current.language
                let availability = LanguageAvailability()
                let status = try? await availability.status(for: "hello", to: target)
                switch status {
                case .installed:
                    box.setAvailability(installed: true, prompt: false)
                case .supported:
                    box.setAvailability(installed: false, prompt: true)
                default:
                    box.setAvailability(installed: false, prompt: false)
                }
                var seen = 0
                while !Task.isCancelled {
                    let generation = box.snapshot().generation
                    if box.allowsTranslation(), generation > 0, generation != seen || configuration == nil {
                        seen = generation
                        configuration = TranslationSession.Configuration(source: nil, target: target)
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
    }
}
