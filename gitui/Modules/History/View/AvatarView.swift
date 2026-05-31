// MARK: - AvatarView.swift

import Cocoa

class AvatarView: NSView {
    var name: String = "" { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2

        let palette: [NSColor] = [
            NSColor(red: 0.22, green: 0.54, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1.0),
            NSColor(red: 0.50, green: 0.47, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.85, green: 0.35, blue: 0.19, alpha: 1.0),
            NSColor(red: 0.83, green: 0.33, blue: 0.49, alpha: 1.0),
        ]
        ctx.setFillColor(palette[abs(name.hashValue) % palette.count].cgColor)
        ctx.fillEllipse(in: bounds)

        let parts = name.components(separatedBy: " ")
        var initials = ""
        if let f = parts.first?.prefix(1) { initials += f }
        if parts.count > 1, let l = parts.last?.prefix(1) { initials += l }
        initials = initials.uppercased()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: radius * 0.9, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let sz = initials.size(withAttributes: attrs)
        initials.draw(in: CGRect(x: center.x - sz.width / 2, y: center.y - sz.height / 2,
                                 width: sz.width, height: sz.height), withAttributes: attrs)
    }
}
