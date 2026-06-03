// MARK: - SidebarRepositoryCellView.swift

import Cocoa

class SidebarRepositoryCellView: NSTableCellView {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BookmarkCell")

    @IBOutlet weak var repoIcon: NSImageView!
    @IBOutlet weak var pathLabel: NSTextField!
    @IBOutlet weak var statsLabel: NSTextField!
    @IBOutlet weak var dividerView: NSView!

    override nonisolated func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated {
            identifier = Self.reuseIdentifier
            wantsLayer = true
            layer?.cornerRadius = 6
            dividerView.wantsLayer = true
            dividerView.layer?.backgroundColor = NSColor.gitFlowBorder.withAlphaComponent(0.4).cgColor
            repoIcon.imageScaling = .scaleProportionallyUpOrDown
            textField?.lineBreakMode = .byTruncatingTail
            pathLabel.lineBreakMode = .byTruncatingHead
        }
    }

    static func instantiate() -> SidebarRepositoryCellView? {
        let bundle = Bundle(for: SidebarRepositoryCellView.self)
        guard let nib = NSNib(nibNamed: "SidebarRepositoryCellView", bundle: bundle) else {
            return nil
        }

        var topLevelObjects: NSArray?
        guard nib.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects) else {
            return nil
        }

        return topLevelObjects?.first(where: { $0 is SidebarRepositoryCellView }) as? SidebarRepositoryCellView
    }

    func configure(bookmark: RepositoryBookmark,
                   isActive: Bool,
                   stats: (added: Int, removed: Int)?,
                   showDivider: Bool) {
        layer?.backgroundColor = NSColor.clear.cgColor

        textField?.stringValue = bookmark.name
        textField?.font = isActive
            ? NSFont.systemFont(ofSize: 13, weight: .semibold)
            : NSFont.systemFont(ofSize: 13, weight: .medium)
        textField?.textColor = isActive ? NSColor.m3Primary : NSColor.labelColor

        pathLabel.stringValue = bookmark.path
        pathLabel.textColor = isActive
            ? NSColor.gitFlowAccent.withAlphaComponent(0.7)
            : NSColor.secondaryLabelColor

        if #available(macOS 11.0, *) {
            repoIcon.contentTintColor = isActive ? NSColor.gitFlowAccent : NSColor.secondaryLabelColor
        }

        if let stats, stats.added > 0 || stats.removed > 0 {
            let result = NSMutableAttributedString()

            if stats.added > 0 {
                result.append(NSAttributedString(string: "+\(stats.added)", attributes: [
                    .foregroundColor: NSColor.gitFlowStagedAddText,
                    .font: NSFont(name: "SF Mono", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                ]))
            }

            if stats.added > 0 && stats.removed > 0 {
                result.append(NSAttributedString(string: " ", attributes: [
                    .font: NSFont.systemFont(ofSize: 11)
                ]))
            }

            if stats.removed > 0 {
                result.append(NSAttributedString(string: "-\(stats.removed)", attributes: [
                    .foregroundColor: NSColor.gitFlowStagedDeleteText,
                    .font: NSFont(name: "SF Mono", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                ]))
            }

            statsLabel.attributedStringValue = result
        } else {
            statsLabel.stringValue = ""
        }

        dividerView.isHidden = !showDivider
    }
}
