// MARK: - DiffTextView.swift

import Cocoa

struct DiffTextGutterEntry {
    let oldLineNumber: String
    let newLineNumber: String
    let backgroundColor: NSColor?
}

protocol DiffTextViewHunkDelegate: AnyObject {
    func diffTextView(_ view: DiffTextView, didRequestStageHunk hunk: DiffHunk)
    func diffTextView(_ view: DiffTextView, didRequestDiscardHunk hunk: DiffHunk)
    func diffTextView(_ view: DiffTextView, didRequestUnstageHunk hunk: DiffHunk)
}

class DiffTextView: NSTextView {

    weak var hunkDelegate: DiffTextViewHunkDelegate?
    var hunks: [DiffHunk] = []
    var isShowingUnstagedDiff: Bool = true
    var lineNumberPrefixLength: Int = 0
    var gutterEntries: [DiffTextGutterEntry] = []

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        if let container {
            super.init(frame: frameRect, textContainer: container)
        } else {
            let textStorage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)
            super.init(frame: frameRect, textContainer: textContainer)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard !hunks.isEmpty else { return menu }

        let pt = convert(event.locationInWindow, from: nil)
        let charIdx = characterIndexForInsertion(at: pt)
        let line = lineIndex(at: charIdx)

        guard let hunk = hunks.first(where: { line >= $0.startLineInText && line <= $0.endLineInText }) else {
            return menu
        }

        if !menu.items.isEmpty {
            menu.insertItem(NSMenuItem.separator(), at: 0)
        }

        if isShowingUnstagedDiff {
            let stageItem = NSMenuItem(title: "Stage this hunk", action: #selector(stageHunkClicked(_:)), keyEquivalent: "")
            stageItem.representedObject = hunk
            stageItem.target = self
            menu.insertItem(stageItem, at: 0)

            let discardItem = NSMenuItem(title: "Discard this hunk", action: #selector(discardHunkClicked(_:)), keyEquivalent: "")
            discardItem.representedObject = hunk
            discardItem.target = self
            menu.insertItem(discardItem, at: 1)
        } else {
            let unstageItem = NSMenuItem(title: "Unstage this hunk", action: #selector(unstageHunkClicked(_:)), keyEquivalent: "")
            unstageItem.representedObject = hunk
            unstageItem.target = self
            menu.insertItem(unstageItem, at: 0)
        }

        return menu
    }

    private func lineIndex(at charIndex: Int) -> Int {
        let text = string as NSString
        var count = 0
        let end = min(charIndex, text.length)
        for i in 0..<end {
            if text.character(at: i) == 10 { count += 1 }
        }
        return count
    }

    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0 else {
            super.copy(sender)
            return
        }

        let selectedText = (string as NSString).substring(with: selectedRange)
        let cleanedText = stripLineNumberPrefixes(from: selectedText)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(cleanedText, forType: .string)
    }

    private func stripLineNumberPrefixes(from text: String) -> String {
        guard lineNumberPrefixLength > 0 else { return text }

        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let lineString = String(line)
                guard lineString.count >= lineNumberPrefixLength else { return lineString }

                let prefix = String(lineString.prefix(lineNumberPrefixLength))
                let digitSlice = prefix.dropLast(2)
                let hasLineNumberPrefix = prefix.hasSuffix("  ")
                    && digitSlice.contains(where: { $0.isNumber })
                    && digitSlice.allSatisfy { $0.isWhitespace || $0.isNumber }

                guard hasLineNumberPrefix else { return lineString }
                return String(lineString.dropFirst(lineNumberPrefixLength))
            }
            .joined(separator: "\n")
    }

    @objc private func stageHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestStageHunk: hunk)
    }

    @objc private func discardHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestDiscardHunk: hunk)
    }

    @objc private func unstageHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestUnstageHunk: hunk)
    }
}

final class DiffTextDocumentView: NSView {
    let textView: DiffTextView
    private let gutterView = DiffTextGutterView()
    private let gutterPadding: CGFloat = 8
    private(set) var gutterWidth: CGFloat = 0

    override var isFlipped: Bool { true }

    init(textView: DiffTextView) {
        self.textView = textView
        super.init(frame: .zero)
        autoresizesSubviews = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        gutterView.textView = textView
        addSubview(gutterView)
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(entries: [DiffTextGutterEntry], textViewSize: NSSize) {
        gutterView.entries = entries
        gutterWidth = calculatedGutterWidth(for: entries, font: textView.font)

        let totalWidth = gutterWidth + textViewSize.width
        let totalHeight = max(textViewSize.height, 1)
        frame = NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight))

        gutterView.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: totalHeight)
        gutterView.needsDisplay = true

        textView.frame = NSRect(x: gutterWidth, y: 0, width: textViewSize.width, height: totalHeight)
    }

    private func calculatedGutterWidth(for entries: [DiffTextGutterEntry], font: NSFont?) -> CGFloat {
        let resolvedFont = font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let digits = max(String(max(entries.count, 1)).count, 1)
        let sample = String(repeating: "8", count: digits)
        let numberWidth = ceil((sample as NSString).size(withAttributes: [.font: resolvedFont]).width)
        let columnSpacing: CGFloat = 8
        return numberWidth * 2 + columnSpacing + gutterPadding * 2
    }
}

private final class DiffTextGutterView: NSView {
    weak var textView: DiffTextView?
    var entries: [DiffTextGutterEntry] = []

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView, let font = textView.font else { return }

        let lineHeight = ceil(font.ascender - font.descender + font.leading) + 2
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let columnSpacing: CGFloat = 8

        for (index, entry) in entries.enumerated() {
            let y = textView.textContainerInset.height + CGFloat(index) * lineHeight
            let rowRect = NSRect(x: 0, y: y, width: bounds.width, height: lineHeight)

            if rowRect.maxY < dirtyRect.minY || rowRect.minY > dirtyRect.maxY {
                continue
            }

            if let backgroundColor = entry.backgroundColor {
                backgroundColor.setFill()
                rowRect.fill()
            }

            let lineAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.gitFlowDiffLineNum,
                .paragraphStyle: paragraphStyle
            ]

            let columnWidth = (bounds.width - columnSpacing - 16) / 2
            let oldNumberRect = NSRect(x: 0, y: y, width: columnWidth, height: lineHeight)
            let newNumberRect = NSRect(x: columnWidth + columnSpacing, y: y, width: columnWidth, height: lineHeight)

            (entry.oldLineNumber as NSString).draw(in: oldNumberRect, withAttributes: lineAttributes)
            (entry.newLineNumber as NSString).draw(in: newNumberRect, withAttributes: lineAttributes)
        }
    }
}
