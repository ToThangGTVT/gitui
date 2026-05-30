// MARK: - WelcomePlaceholderView.swift

import Cocoa

class WelcomePlaceholderView: NSView {
    
    @IBOutlet weak var contentView: NSView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var subtitleLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFromNib()
    }
    
    private func setupFromNib() {
        let bundle = Bundle(for: type(of: self))
        let nibName = String(describing: type(of: self))
        guard let nib = NSNib(nibNamed: nibName, bundle: bundle) else {
            print("Error: Could not load nib named \(nibName)")
            return
        }
        var topLevelObjects: NSArray? = nil
        if nib.instantiate(withOwner: self, topLevelObjects: &topLevelObjects) {
            if let view = topLevelObjects?.first(where: { $0 is NSView }) as? NSView {
                view.frame = self.bounds
                view.autoresizingMask = [.width, .height]
                self.addSubview(view)
                self.contentView = view
            }
        }
    }
}
