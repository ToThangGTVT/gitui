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
                
                // Styling (macOS 26 glassmorphism)
                self.wantsLayer = true
                self.layer?.backgroundColor = NSColor.clear.cgColor
                
                borderView.wantsLayer = true
                borderView.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
                
                configureButtonIcons()
            }
        }
    }
    
    private func configureButtonIcons() {
        let buttons: [(NSButton?, String, String)] = [
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
        
        func createAttributedTitle(_ title: String) -> NSAttributedString {
            let result = NSMutableAttributedString()
            
            // 1. Spacing character (newline with font size 3)
            let spacer = NSAttributedString(string: "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 3)
            ])
            result.append(spacer)
            
            // 2. Title text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let textAttr = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.controlAccentColor,
                .paragraphStyle: paragraphStyle
            ])
            result.append(textAttr)
            
            return result
        }
        
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            for (btn, title, symbol) in buttons {
                if let button = btn {
                    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?.withSymbolConfiguration(config)
                    button.imagePosition = .imageAbove
                    button.attributedTitle = createAttributedTitle(title)
                }
            }
        } else {
            for (btn, title, _) in buttons {
                if let button = btn {
                    button.image = NSImage(named: NSImage.actionTemplateName)
                    button.imagePosition = .imageAbove
                    button.attributedTitle = createAttributedTitle(title)
                }
            }
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
}
