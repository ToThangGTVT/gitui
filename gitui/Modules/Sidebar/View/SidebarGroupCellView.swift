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

    func configure(title: String) {
        identifier = Self.reuseIdentifier
        textField?.stringValue = title
        textField?.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        textField?.textColor = NSColor.secondaryLabelColor
    }
}
