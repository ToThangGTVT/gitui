import Cocoa

class SidebarOutlineItemCellView: NSTableCellView {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("SidebarOutlineItemCell")
    @IBOutlet private weak var iconWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var labelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var statusLabel: NSTextField!
    @IBOutlet private weak var labelTrailingConstraint: NSLayoutConstraint!

    private let visibleIconWidth: CGFloat = 14
    private let visibleLabelSpacing: CGFloat = 7
    private let compactTrailingInset: CGFloat = 8
    private let expandedTrailingInset: CGFloat = 40

    static func instantiate() -> SidebarOutlineItemCellView? {
        let bundle = Bundle(for: SidebarOutlineItemCellView.self)
        guard let nib = NSNib(nibNamed: "SidebarOutlineItemCellView", bundle: bundle) else {
            return nil
        }

        var topLevelObjects: NSArray?
        guard nib.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects) else {
            return nil
        }

        return topLevelObjects?.first(where: { $0 is SidebarOutlineItemCellView }) as? SidebarOutlineItemCellView
    }

    func configure(title: String,
                   systemSymbolName: String?,
                   fallbackImageName: String?,
                   accessibilityDescription: String,
                   font: NSFont,
                   textColor: NSColor,
                   tintColor: NSColor,
                   syncStatus: NSAttributedString?) {
        identifier = Self.reuseIdentifier
        textField?.stringValue = title
        textField?.font = font
        textField?.textColor = textColor
        statusLabel.attributedStringValue = syncStatus ?? NSAttributedString(string: "")
        statusLabel.isHidden = syncStatus == nil

        if let systemSymbolName {
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                imageView?.image = NSImage(
                    systemSymbolName: systemSymbolName,
                    accessibilityDescription: accessibilityDescription
                )?.withSymbolConfiguration(config)
                imageView?.contentTintColor = tintColor
            } else if let fallbackImageName {
                imageView?.image = NSImage(named: NSImage.Name(fallbackImageName))
            }
        } else if let fallbackImageName {
            imageView?.image = NSImage(named: NSImage.Name(fallbackImageName))
            imageView?.contentTintColor = tintColor
        } else {
            imageView?.image = nil
        }

        let hasIcon = imageView?.image != nil
        imageView?.isHidden = !hasIcon
        imageView?.imageScaling = .scaleProportionallyUpOrDown
        iconWidthConstraint.constant = hasIcon ? visibleIconWidth : 0
        labelLeadingConstraint.constant = hasIcon ? visibleLabelSpacing : 0
        labelTrailingConstraint.constant = syncStatus == nil ? compactTrailingInset : expandedTrailingInset
    }
}
