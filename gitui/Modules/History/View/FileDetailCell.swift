// MARK: - FileDetailCell.swift

import Cocoa

class FileDetailCell: NSTableCellView {
    @IBOutlet weak var statusBadge: NSTextField!
}

class CenteredTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let titleSize = self.cellSize(forBounds: rect)
        var titleRect = super.titleRect(forBounds: rect)
        let diff = rect.size.height - titleSize.height
        if diff > 0 {
            titleRect.origin.y += diff / 2
            titleRect.size.height = titleSize.height
        }
        return titleRect
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let titleRect = self.titleRect(forBounds: cellFrame)
        super.drawInterior(withFrame: titleRect, in: controlView)
    }
}
