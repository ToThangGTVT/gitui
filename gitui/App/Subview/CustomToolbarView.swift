// MARK: - CustomToolbarView.swift

import Cocoa

protocol CustomToolbarViewDelegate: AnyObject {
    func toolbarDidClickCommit()
    func toolbarDidClickPull()
    func toolbarDidClickPush()
    func toolbarDidClickFetch()
    func toolbarDidClickBranch()
    func toolbarDidClickMerge()
    func toolbarDidClickStash()
    func toolbarDidClickViewRemote()
    func toolbarDidClickShowInFinder()
    func toolbarDidClickTerminal()
    func toolbarDidClickSettings()
}

class CustomToolbarView: NSView {
    
    weak var delegate: CustomToolbarViewDelegate?
    
    @IBOutlet weak var contentView: NSView!
    @IBOutlet weak var borderView: NSView!
    
    @IBOutlet weak var commitButton: NSButton!
    @IBOutlet weak var pullButton: NSButton!
    @IBOutlet weak var pushButton: NSButton!
    @IBOutlet weak var fetchButton: NSButton!
    @IBOutlet weak var branchButton: NSButton!
    @IBOutlet weak var mergeButton: NSButton!
    @IBOutlet weak var stashButton: NSButton!
    @IBOutlet weak var remoteButton: NSButton!
    @IBOutlet weak var finderButton: NSButton!
    @IBOutlet weak var terminalButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!
    
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
                
                // Styling matching the screenshot design
                self.wantsLayer = true
                self.layer?.backgroundColor = NSColor.clear.cgColor
                
                borderView.wantsLayer = true
                borderView.layer?.backgroundColor = NSColor.m3OutlineFaint.cgColor
                borderView.layer?.backgroundColor = NSColor.clear.cgColor
                
                configureButtonIcons()
            }
        }
    }
    
    private func configureButtonIcons() {
        let configs: [(NSButton?, String, String)] = [
            (commitButton, "Commit", "plus.circle"),
            (pullButton, "Pull", "arrow.down.circle"),
            (pushButton, "Push", "arrow.up.circle"),
            (fetchButton, "Fetch", "arrow.clockwise.circle"),
            (branchButton, "Branch", "arrow.triangle.branch"),
            (mergeButton, "Merge", "arrow.triangle.merge"),
            (stashButton, "Stash", "archivebox"),
            (remoteButton, "View Remote", "globe"),
            (finderButton, "Show in Finder", "folder"),
            (terminalButton, "Terminal", "terminal"),
            (settingsButton, "Settings", "gearshape")
        ]
        
        for (idx, (btn, title, iconName)) in configs.enumerated() {
            guard let btn = btn else { continue }
            let isCommit = (idx == 0)
            
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                var image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
                if isCommit {
                    image = image?.withSymbolConfiguration(config.applying(.init(paletteColors: [NSColor.systemBlue])))
                } else {
                    image = image?.withSymbolConfiguration(config)
                }
                btn.image = image
            }
            
            let result = NSMutableAttributedString()
            let spacer = NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 4)])
            result.append(spacer)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let textAttr = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isCommit ? NSColor.systemBlue : NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ])
            result.append(textAttr)
            
            btn.attributedTitle = result
            btn.imagePosition = .imageAbove
            btn.imageScaling = .scaleProportionallyDown
            btn.isBordered = false
        }
    }
    
    // MARK: - Button Actions
    
    @IBAction func commitClicked(_ sender: Any) {
        delegate?.toolbarDidClickCommit()
    }
    
    @IBAction func pullClicked(_ sender: Any) {
        delegate?.toolbarDidClickPull()
    }
    
    @IBAction func pushClicked(_ sender: Any) {
        delegate?.toolbarDidClickPush()
    }
    
    @IBAction func fetchClicked(_ sender: Any) {
        delegate?.toolbarDidClickFetch()
    }
    
    @IBAction func branchClicked(_ sender: Any) {
        delegate?.toolbarDidClickBranch()
    }
    
    @IBAction func mergeClicked(_ sender: Any) {
        delegate?.toolbarDidClickMerge()
    }
    
    @IBAction func stashClicked(_ sender: Any) {
        delegate?.toolbarDidClickStash()
    }
    
    @IBAction func viewRemoteClicked(_ sender: Any) {
        delegate?.toolbarDidClickViewRemote()
    }
    
    @IBAction func showInFinderClicked(_ sender: Any) {
        delegate?.toolbarDidClickShowInFinder()
    }
    
    @IBAction func terminalClicked(_ sender: Any) {
        delegate?.toolbarDidClickTerminal()
    }
    
    @IBAction func settingsClicked(_ sender: Any) {
        delegate?.toolbarDidClickSettings()
    }
    
    // MARK: - Badges
    
    private func updateBadge(for button: NSButton, count: Int, identifier: String, color: NSColor) {
        if count > 0 {
            var badgeLabel: NSTextField!
            if let existing = button.subviews.first(where: { $0.identifier?.rawValue == identifier }) as? NSTextField {
                badgeLabel = existing
            } else {
                badgeLabel = NSTextField(labelWithString: "")
                badgeLabel.identifier = NSUserInterfaceItemIdentifier(identifier)
                badgeLabel.wantsLayer = true
                badgeLabel.layer?.cornerRadius = 6
                badgeLabel.layer?.masksToBounds = true
                badgeLabel.alignment = .center
                badgeLabel.font = NSFont.systemFont(ofSize: 8, weight: .bold)
                badgeLabel.textColor = .white
                badgeLabel.translatesAutoresizingMaskIntoConstraints = false
                
                button.addSubview(badgeLabel)
                
                NSLayoutConstraint.activate([
                    badgeLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: -6),
                    badgeLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 4),
                    badgeLabel.heightAnchor.constraint(equalToConstant: 12),
                    badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 12)
                ])
            }
            badgeLabel.layer?.backgroundColor = color.cgColor
            badgeLabel.stringValue = "\(count)"
        } else {
            button.subviews.first(where: { $0.identifier?.rawValue == identifier })?.removeFromSuperview()
        }
    }
    
    func setPullBadge(count: Int) {
        updateBadge(for: pullButton, count: count, identifier: "pullBadge", color: NSColor.systemOrange)
    }
    
    func setPushBadge(count: Int) {
        updateBadge(for: pushButton, count: count, identifier: "pushBadge", color: NSColor.systemGreen)
    }
}
