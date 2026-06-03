import Cocoa

@IBDesignable
class GitActionButton: NSControl {
    
    @IBOutlet var contentView: NSView!
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var badgeLabel: NSTextField!
    
    // Properties to configure via code or IB
    @IBInspectable var title: String = "Button" {
        didSet { titleLabel.stringValue = title }
    }
    
    @IBInspectable var iconName: String = "circle" {
        didSet { updateIcon() }
    }
    
    @IBInspectable var iconColor: NSColor = .labelColor {
        didSet { updateIcon() }
    }
    
    @IBInspectable var titleColor: NSColor = .labelColor {
        didSet { titleLabel.textColor = titleColor }
    }
    
    var badgeCount: Int = 0 {
        didSet {
            if badgeCount > 0 {
                badgeLabel.stringValue = "\(badgeCount)"
                badgeLabel.isHidden = false
            } else {
                badgeLabel.isHidden = true
            }
        }
    }
    
    var badgeColor: NSColor = .systemOrange {
        didSet { badgeLabel.layer?.backgroundColor = badgeColor.cgColor }
    }
    
    // Click action block
    var actionBlock: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let bundle = Bundle(for: type(of: self))
        let nibName = String(describing: type(of: self))
        guard let nib = NSNib(nibNamed: nibName, bundle: bundle) else { return }
        
        var topLevelObjects: NSArray? = nil
        if nib.instantiate(withOwner: self, topLevelObjects: &topLevelObjects) {
            if let view = topLevelObjects?.first(where: { $0 is NSView }) as? NSView {
                view.frame = self.bounds
                view.autoresizingMask = [.width, .height]
                self.addSubview(view)
                
                titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                
                badgeLabel.wantsLayer = true
                badgeLabel.layer?.cornerRadius = 8
                badgeLabel.layer?.masksToBounds = true
                badgeLabel.backgroundColor = .clear
                badgeLabel.layer?.backgroundColor = badgeColor.cgColor
                badgeLabel.isHidden = true
                
                updateIcon()
            }
        }
    }
    
    private func updateIcon() {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: title) {
                iconImageView.image = image.withSymbolConfiguration(config.applying(.init(paletteColors: [iconColor])))
            }
        }
    }
    
    // Tracking area for hover effect and click
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        contentView.layer?.cornerRadius = 6
    }
    
    override func mouseExited(with event: NSEvent) {
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func mouseDown(with event: NSEvent) {
        contentView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
    }
    
    override func mouseUp(with event: NSEvent) {
        contentView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            // Trigger target-action
            if let target = target, let action = action {
                NSApp.sendAction(action, to: target, from: self)
            }
            actionBlock?()
        }
    }
}
