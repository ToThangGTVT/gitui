import Cocoa

class SidebarOutlineItemCellView: NSTableCellView {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("SidebarOutlineItemCell")

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
                   systemSymbolName: String,
                   fallbackImageName: String?,
                   accessibilityDescription: String,
                   font: NSFont,
                   textColor: NSColor,
                   tintColor: NSColor) {
        identifier = Self.reuseIdentifier
        textField?.stringValue = title
        textField?.font = font
        textField?.textColor = textColor

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            imageView?.image = NSImage(
                systemSymbolName: systemSymbolName,
                accessibilityDescription: accessibilityDescription
            )?.withSymbolConfiguration(config)
            imageView?.contentTintColor = tintColor
        } else if let fallbackImageName {
            imageView?.image = NSImage(named: NSImage.Name(fallbackImageName))
        }

        imageView?.imageScaling = .scaleProportionallyUpOrDown
    }
}
