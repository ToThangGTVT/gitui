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
        hunkLabel.isSelectable = true

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

    private let oldLineNumLabel = NSTextField(labelWithString: "")
    private let newLineNumLabel = NSTextField(labelWithString: "")
    private let sep = NSView()
    private let contentLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        oldLineNumLabel.font = NSFont.m3Mono
        oldLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
        oldLineNumLabel.alignment = .right
        oldLineNumLabel.translatesAutoresizingMaskIntoConstraints = false
        oldLineNumLabel.isSelectable = true
        addSubview(oldLineNumLabel)
        
        newLineNumLabel.font = NSFont.m3Mono
        newLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
        newLineNumLabel.alignment = .right
        newLineNumLabel.translatesAutoresizingMaskIntoConstraints = false
        newLineNumLabel.isSelectable = true
        addSubview(newLineNumLabel)

        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.m3OutlineFaint.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep)

        contentLabel.font = NSFont.m3Mono
        contentLabel.lineBreakMode = .byClipping
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.isSelectable = true
        addSubview(contentLabel)

        NSLayoutConstraint.activate([
            oldLineNumLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            oldLineNumLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            oldLineNumLabel.widthAnchor.constraint(equalToConstant: 42),
            
            newLineNumLabel.leadingAnchor.constraint(equalTo: oldLineNumLabel.trailingAnchor, constant: 4),
            newLineNumLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            newLineNumLabel.widthAnchor.constraint(equalToConstant: 42),

            sep.leadingAnchor.constraint(equalTo: newLineNumLabel.trailingAnchor, constant: 4),
            sep.centerYAnchor.constraint(equalTo: centerYAnchor),
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.heightAnchor.constraint(equalTo: heightAnchor),

            contentLabel.leadingAnchor.constraint(equalTo: sep.trailingAnchor, constant: 12),
            contentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    func configure(with line: DiffLine) {
        let contentStr = line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())
        
        switch line.kind {
        case .context(let oldLn, let newLn):
            oldLineNumLabel.stringValue = "\(oldLn)"
            newLineNumLabel.stringValue = "\(newLn)"
            oldLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            newLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            contentLabel.stringValue = " " + contentStr
            contentLabel.textColor = NSColor.m3OnSurfaceVariant
            layer?.backgroundColor = NSColor.clear.cgColor

        case .added(let newLn):
            oldLineNumLabel.stringValue = ""
            newLineNumLabel.stringValue = "\(newLn)"
            oldLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            newLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            contentLabel.stringValue = "+" + contentStr
            contentLabel.textColor = NSColor(hex: "#0B5B27")
            layer?.backgroundColor = NSColor(hex: "#E6F4EA").cgColor

        case .removed(let oldLn):
            oldLineNumLabel.stringValue = "\(oldLn)"
            newLineNumLabel.stringValue = ""
            oldLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            newLineNumLabel.textColor = NSColor.m3OnSurfaceFaint
            contentLabel.stringValue = "-" + contentStr
            contentLabel.textColor = NSColor(hex: "#A50E0E")
            layer?.backgroundColor = NSColor(hex: "#FCE8E6").cgColor

        case .fileHeader:
            oldLineNumLabel.stringValue = ""
            newLineNumLabel.stringValue = ""
            contentLabel.stringValue = line.rawText
            contentLabel.textColor = NSColor.m3OnSurfaceVariant
            layer?.backgroundColor = NSColor.m3SurfaceContainerHigh.cgColor

        case .hunkHeader:
            break // rendered by HunkHeaderCellView
        }
    }
}
