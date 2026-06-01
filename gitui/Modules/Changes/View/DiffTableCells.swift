// MARK: - DiffTableCells.swift

import Cocoa

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
        layer?.backgroundColor = HunkHeaderCellView.background.cgColor
    }

    @objc private func stageTapped()   { onStageHunk?() }
    @objc private func discardTapped() { onDiscardHunk?() }
    @objc private func unstageTapped() { onUnstageHunk?() }
}

// MARK: - DiffLineCellView

class DiffLineCellView: NSView {

    private let lineNumLabel = NSTextField(labelWithString: "")
    private let signLabel = NSTextField(labelWithString: "")
    private let sep = NSView()
    private let contentLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        let gutterFont  = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let contentFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        lineNumLabel.font = gutterFont
        lineNumLabel.textColor = .secondaryLabelColor
        lineNumLabel.alignment = .right
        lineNumLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lineNumLabel)
        
        signLabel.font = gutterFont
        signLabel.textColor = .secondaryLabelColor
        signLabel.alignment = .center
        signLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(signLabel)

        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep)

        contentLabel.font = contentFont
        contentLabel.lineBreakMode = .byClipping
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)

        NSLayoutConstraint.activate([
            lineNumLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            lineNumLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            lineNumLabel.widthAnchor.constraint(equalToConstant: 40),
            
            signLabel.leadingAnchor.constraint(equalTo: lineNumLabel.trailingAnchor, constant: 2),
            signLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            signLabel.widthAnchor.constraint(equalToConstant: 10),

            sep.leadingAnchor.constraint(equalTo: signLabel.trailingAnchor, constant: 2),
            sep.centerYAnchor.constraint(equalTo: centerYAnchor),
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.heightAnchor.constraint(equalTo: heightAnchor),

            contentLabel.leadingAnchor.constraint(equalTo: sep.trailingAnchor, constant: 6),
            contentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    func configure(with line: DiffLine) {
        switch line.kind {
        case .context(_, let new):
            lineNumLabel.stringValue = "\(new)"
            signLabel.stringValue = ""
            lineNumLabel.textColor = .tertiaryLabelColor
            signLabel.textColor = .tertiaryLabelColor
            contentLabel.stringValue = line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())
            contentLabel.textColor = .labelColor
            layer?.backgroundColor = NSColor.clear.cgColor

        case .added(let ln):
            lineNumLabel.stringValue = "\(ln)"
            signLabel.stringValue = "+"
            lineNumLabel.textColor = .gitFlowStagedAddText
            signLabel.textColor = .gitFlowStagedAddText
            contentLabel.stringValue = line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())
            contentLabel.textColor = .labelColor
            layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor

        case .removed(let ln):
            lineNumLabel.stringValue = "\(ln)"
            signLabel.stringValue = "-"
            lineNumLabel.textColor = .gitFlowStagedDeleteText
            signLabel.textColor = .gitFlowStagedDeleteText
            contentLabel.stringValue = line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())
            contentLabel.textColor = .labelColor
            layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor

        case .fileHeader:
            lineNumLabel.stringValue = ""
            signLabel.stringValue = ""
            contentLabel.stringValue = line.rawText
            contentLabel.textColor = .secondaryLabelColor
            layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor

        case .hunkHeader:
            break // rendered by HunkHeaderCellView
        }
    }
}
