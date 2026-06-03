import Cocoa

class SidebarGroupCellView: NSTableCellView {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("GroupCell")

    static func instantiate() -> SidebarGroupCellView? {
        let bundle = Bundle(for: SidebarGroupCellView.self)
        guard let nib = NSNib(nibNamed: "SidebarGroupCellView", bundle: bundle) else {
            return nil
        }

        var topLevelObjects: NSArray?
        guard nib.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects) else {
            return nil
        }

        return topLevelObjects?.first(where: { $0 is SidebarGroupCellView }) as? SidebarGroupCellView
    }

    func configure(title: String,
                   systemSymbolName: String?,
                   fallbackImageName: String?,
                   accessibilityDescription: String,
                   tintColor: NSColor = .secondaryLabelColor) {
        identifier = Self.reuseIdentifier
        textField?.stringValue = title
        textField?.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        textField?.textColor = NSColor.secondaryLabelColor

        if #available(macOS 11.0, *), let systemSymbolName {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            imageView?.image = NSImage(
                systemSymbolName: systemSymbolName,
                accessibilityDescription: accessibilityDescription
            )?.withSymbolConfiguration(config)
            imageView?.contentTintColor = tintColor
        } else if let fallbackImageName {
            imageView?.image = NSImage(named: NSImage.Name(fallbackImageName))
        } else {
            imageView?.image = nil
        }

        imageView?.isHidden = imageView?.image == nil
        imageView?.imageScaling = .scaleProportionallyUpOrDown
    }
}
