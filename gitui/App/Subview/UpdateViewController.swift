// MARK: - UpdateViewController.swift
// A highly-polished custom dialog to notify users of a new update.

import Cocoa

class UpdateViewController: NSViewController {
    
    private let release: GitHubRelease
    private let currentVersion: String
    
    // UI elements
    @IBOutlet private weak var headerIcon: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var versionBadgeContainer: NSStackView!
    @IBOutlet private weak var notesLabel: NSTextField!
    @IBOutlet private weak var logScrollView: NSScrollView!
    @IBOutlet private var logTextView: NSTextView!
    @IBOutlet private weak var downloadButton: NSButton!
    @IBOutlet private weak var laterButton: NSButton!
    
    init(release: GitHubRelease, currentVersion: String) {
        self.release = release
        self.currentVersion = currentVersion
        super.init(nibName: "UpdateViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            headerIcon.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        headerIcon.contentTintColor = NSColor.controlAccentColor
        
        // Running version badge
        let runningLabel = createBadge(text: "Current: \(currentVersion)", isAccent: false)
        versionBadgeContainer.addArrangedSubview(runningLabel)
        
        // Arrow indicator
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        arrowLabel.textColor = NSColor.secondaryLabelColor
        versionBadgeContainer.addArrangedSubview(arrowLabel)
        
        // Latest version badge
        let latestLabel = createBadge(text: "Latest: \(release.tagName)", isAccent: true)
        versionBadgeContainer.addArrangedSubview(latestLabel)
        
        notesLabel.stringValue = "Release Notes (\(release.name)):"
        
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 8
        logScrollView.layer?.masksToBounds = true
        logScrollView.layer?.borderWidth = 1
        logScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        logTextView.textContainer?.containerSize = NSSize(width: logScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        logTextView.textContainer?.widthTracksTextView = true
        
        // Format body text if markdown-like
        let cleanBody = release.body.replacingOccurrences(of: "\r\n", with: "\n")
        logTextView.string = cleanBody
    }
    
    private func createBadge(text: String, isAccent: Bool) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 4
        badge.layer?.masksToBounds = true
        
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        
        badge.addSubview(label)
        
        if isAccent {
            badge.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            label.textColor = NSColor.controlAccentColor
        } else {
            badge.layer?.backgroundColor = NSColor.textColor.withAlphaComponent(0.08).cgColor
            label.textColor = NSColor.secondaryLabelColor
        }
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -3)
        ])
        
        return badge
    }
    
    @IBAction private func downloadClicked(_ sender: Any) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
        closeSheet()
    }
    
    @IBAction private func laterClicked(_ sender: Any) {
        closeSheet()
    }
    
    private func closeSheet() {
        guard let sheetWindow = view.window, let parent = sheetWindow.sheetParent else {
            self.dismiss(nil)
            return
        }
        parent.endSheet(sheetWindow)
    }
    
    /// Static helper method to display the update sheet modal.
    static func show(release: GitHubRelease, currentVersion: String, from window: NSWindow? = nil) {
        let updateVC = UpdateViewController(release: release, currentVersion: currentVersion)
        let updateWindow = NSWindow(contentViewController: updateVC)
        updateWindow.styleMask = [.titled, .closable]
        updateWindow.title = "Software Update"
        updateWindow.setContentSize(NSSize(width: 520, height: 380))
        
        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
        if let targetWindow = targetWindow {
            targetWindow.beginSheet(updateWindow, completionHandler: nil)
        }
    }
}
