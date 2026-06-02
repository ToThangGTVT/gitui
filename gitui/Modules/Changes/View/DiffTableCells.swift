// MARK: - DiffTableCells.swift

import Cocoa

// MARK: - NoHighlightRowView

class NoHighlightRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).setFill()
        bounds.fill()
    }
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}

// MARK: - HunkHeaderCellView

class HunkHeaderCellView: NSView {

    var onStageHunk: (() -> Void)?
    var onDiscardHunk: (() -> Void)?
    var onUnstageHunk: (() -> Void)?

    private let hunkLabel = NSTextField(labelWithString: "")
    private let stageButton = NSButton()
    private let discardButton = NSButton()
    private let unstageButton = NSButton()
    // NSStackView collapses hidden arranged subviews automatically
    private let actionStack = NSStackView()

    private static let background = NSColor(name: nil) { trait in
        if trait.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.25, alpha: 1.0)
        }
        return NSColor(white: 0.95, alpha: 1.0)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = HunkHeaderCellView.background.cgColor

        hunkLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        hunkLabel.textColor = .secondaryLabelColor
        hunkLabel.lineBreakMode = .byTruncatingTail
        hunkLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hunkLabel.isSelectable = false

        for (btn, title, sel) in [
            (stageButton,   "Stage Hunk",   #selector(stageTapped)),
            (discardButton, "Discard",       #selector(discardTapped)),
            (unstageButton, "Unstage Hunk",  #selector(unstageTapped)),
        ] as [(NSButton, String, Selector)] {
            btn.title = title
            btn.bezelStyle = .inline
            btn.controlSize = .mini
            btn.target = self
            btn.action = sel
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        actionStack.orientation = .horizontal
        actionStack.spacing = 6
        actionStack.alignment = .centerY
        actionStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionStack.addArrangedSubview(stageButton)
        actionStack.addArrangedSubview(discardButton)
        actionStack.addArrangedSubview(unstageButton)

        let outerStack = NSStackView(views: [hunkLabel, actionStack])
        outerStack.orientation = .horizontal
        outerStack.spacing = 8
        outerStack.alignment = .centerY
        outerStack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(headerText: String, isUnstagedDiff: Bool, isReadOnly: Bool = false) {
        // Clean up the "@@ -53,5 +53,5 @@ text" to make it more user-friendly
        var friendlyText = headerText
        if let range = headerText.range(of: "@@") {
            if let endRange = headerText.range(of: "@@", options: [], range: range.upperBound..<headerText.endIndex) {
                let contextText = headerText[endRange.upperBound...].trimmingCharacters(in: .whitespaces)
                friendlyText = contextText.isEmpty ? "Code block" : contextText
            }
        }
        
        hunkLabel.stringValue = friendlyText
        hunkLabel.font = NSFont.m3Mono
        hunkLabel.textColor = NSColor.m3Primary
        self.layer?.backgroundColor = NSColor.m3Primary.withAlphaComponent(0.08).cgColor
        
        if isReadOnly {
            stageButton.isHidden   = true
            discardButton.isHidden = true
            unstageButton.isHidden = true
        } else {
            stageButton.isHidden   = !isUnstagedDiff
            discardButton.isHidden = !isUnstagedDiff
            unstageButton.isHidden = isUnstagedDiff
        }
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.m3Primary.withAlphaComponent(0.08).cgColor
    }

    @objc private func stageTapped()   { onStageHunk?() }
    @objc private func discardTapped() { onDiscardHunk?() }
    @objc private func unstageTapped() { onUnstageHunk?() }
}

// MARK: - DiffLineCellView

class DiffLineCellView: NSView {

    private let lineNumLabel = NSTextField(labelWithString: "")
    private let sep = NSView()
    private let contentLabel = NSTextField(labelWithString: "")
    private var currentLine: DiffLine?

    private static var addedBg: NSColor {
        NSColor(name: nil) { trait in
            trait.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.04, green: 0.18, blue: 0.04, alpha: 1.0)
                : NSColor(hex: "#E6F4EA")
        }
    }
    private static var addedText: NSColor {
        NSColor(name: nil) { trait in
            trait.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.42, green: 0.88, blue: 0.42, alpha: 1.0)
                : NSColor(hex: "#0B5B27")
        }
    }
    private static var removedBg: NSColor {
        NSColor(name: nil) { trait in
            trait.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.22, green: 0.04, blue: 0.04, alpha: 1.0)
                : NSColor(hex: "#FCE8E6")
        }
    }
    private static var removedText: NSColor {
        NSColor(name: nil) { trait in
            trait.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.96, green: 0.46, blue: 0.46, alpha: 1.0)
                : NSColor(hex: "#A50E0E")
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        lineNumLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        lineNumLabel.textColor = .gitFlowDiffLineNum
        lineNumLabel.alignment = .right
        lineNumLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lineNumLabel)

        contentLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        contentLabel.lineBreakMode = .byClipping
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)

        NSLayoutConstraint.activate([
            lineNumLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            lineNumLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            lineNumLabel.widthAnchor.constraint(equalToConstant: 44),

            contentLabel.leadingAnchor.constraint(equalTo: lineNumLabel.trailingAnchor, constant: 8),
            contentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    func configure(with line: DiffLine) {
        currentLine = line
        applyColors(for: line)
    }

    private func applyColors(for line: DiffLine) {
        let contentStr = line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())

        switch line.kind {
        case .context(_, let newLn):
            lineNumLabel.stringValue = "\(newLn)"
            lineNumLabel.textColor = .gitFlowDiffLineNum
            contentLabel.stringValue = " " + contentStr
            contentLabel.textColor = .gitFlowDiffContextText
            layer?.backgroundColor = NSColor.clear.cgColor

        case .added(let newLn):
            lineNumLabel.stringValue = "\(newLn)"
            lineNumLabel.textColor = DiffLineCellView.addedText
            contentLabel.stringValue = "+" + contentStr
            contentLabel.textColor = DiffLineCellView.addedText
            layer?.backgroundColor = DiffLineCellView.addedBg.cgColor

        case .removed(let oldLn):
            lineNumLabel.stringValue = "\(oldLn)"
            lineNumLabel.textColor = DiffLineCellView.removedText
            contentLabel.stringValue = "-" + contentStr
            contentLabel.textColor = DiffLineCellView.removedText
            layer?.backgroundColor = DiffLineCellView.removedBg.cgColor

        case .fileHeader:
            lineNumLabel.stringValue = ""
            contentLabel.stringValue = line.rawText
            contentLabel.textColor = .gitFlowDiffContextText
            layer?.backgroundColor = NSColor.clear.cgColor

        case .hunkHeader:
            break
        }
    }

    override func updateLayer() {
        super.updateLayer()
        if let line = currentLine {
            applyColors(for: line)
        }
    }
}
