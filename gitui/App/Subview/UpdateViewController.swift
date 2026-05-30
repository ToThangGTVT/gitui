// MARK: - UpdateViewController.swift
// A highly-polished custom dialog to notify users of a new update.

import Cocoa

class UpdateViewController: NSViewController {
    
    private let release: GitHubRelease
    private let currentVersion: String
    
    // UI elements
    private var headerIcon: NSImageView!
    private var titleLabel: NSTextField!
    private var versionBadgeContainer: NSStackView!
    private var notesLabel: NSTextField!
    private var logScrollView: NSScrollView!
    private var logTextView: NSTextView!
    private var downloadButton: NSButton!
    private var laterButton: NSButton!
    
    init(release: GitHubRelease, currentVersion: String) {
        self.release = release
        self.currentVersion = currentVersion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // 1. Icon ImageView
        headerIcon = NSImageView()
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.imageScaling = .scaleProportionallyUpOrDown
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            headerIcon.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        headerIcon.contentTintColor = NSColor.controlAccentColor
        view.addSubview(headerIcon)
        
        // 2. Title Label
        titleLabel = NSTextField(labelWithString: "New Update Available")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        view.addSubview(titleLabel)
        
        // 3. Version comparison badges stack
        versionBadgeContainer = NSStackView()
        versionBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
        versionBadgeContainer.orientation = .horizontal
        versionBadgeContainer.spacing = 8
        versionBadgeContainer.alignment = .centerY
        view.addSubview(versionBadgeContainer)
        
        // Running version badge
        let runningLabel = createBadge(text: "Current: \(currentVersion)", isAccent: false)
        versionBadgeContainer.addArrangedSubview(runningLabel)
        
        // Arrow indicator
        let arrowLabel = NSTextField(labelWithString: "➔")
        arrowLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        arrowLabel.textColor = NSColor.secondaryLabelColor
        versionBadgeContainer.addArrangedSubview(arrowLabel)
        
        // Latest version badge
        let latestLabel = createBadge(text: "Latest: \(release.tagName)", isAccent: true)
        versionBadgeContainer.addArrangedSubview(latestLabel)
        
        // 4. Notes Section Header
        notesLabel = NSTextField(labelWithString: "Release Notes (\(release.name)):")
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        notesLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        notesLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(notesLabel)
        
        // 5. Scroll View for Release Notes
        logScrollView = NSScrollView()
        logScrollView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.hasVerticalScroller = true
        logScrollView.hasHorizontalScroller = false
        logScrollView.autohidesScrollers = true
        logScrollView.borderType = .noBorder
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 8
        logScrollView.layer?.masksToBounds = true
        logScrollView.layer?.borderWidth = 1
        logScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        logScrollView.drawsBackground = true
        logScrollView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        view.addSubview(logScrollView)
        
        // 6. Text View for Release Notes description
        logTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 510, height: 200))
        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.autoresizingMask = [.width]
        logTextView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        logTextView.textColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.textContainer?.containerSize = NSSize(width: 510, height: CGFloat.greatestFiniteMagnitude)
        logTextView.textContainer?.widthTracksTextView = true
        
        // Format body text if markdown-like
        let cleanBody = release.body.replacingOccurrences(of: "\r\n", with: "\n")
        logTextView.string = cleanBody
        logScrollView.documentView = logTextView
        
        // 7. Later Button (Dismiss)
        laterButton = NSButton(title: "Later", target: self, action: #selector(laterClicked(_:)))
        laterButton.translatesAutoresizingMaskIntoConstraints = false
        laterButton.bezelStyle = .rounded
        laterButton.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        view.addSubview(laterButton)
        
        // 8. Download Now Button
        downloadButton = NSButton(title: "Download Now", target: self, action: #selector(downloadClicked(_:)))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.bezelStyle = .rounded
        downloadButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        // Give download button standard focus
        downloadButton.keyEquivalent = "\r" // Enter key
        view.addSubview(downloadButton)
        
        // Setup Auto Layout constraints
        NSLayoutConstraint.activate([
            // Header Icon
            headerIcon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerIcon.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            headerIcon.widthAnchor.constraint(equalToConstant: 32),
            headerIcon.heightAnchor.constraint(equalToConstant: 32),
            
            // Title Label
            titleLabel.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerIcon.centerYAnchor, constant: -8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Version Badges stack
            versionBadgeContainer.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            versionBadgeContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            
            // Release Notes Header
            notesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            notesLabel.topAnchor.constraint(equalTo: headerIcon.bottomAnchor, constant: 20),
            notesLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Scrollview for Logs
            logScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            logScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            logScrollView.topAnchor.constraint(equalTo: notesLabel.bottomAnchor, constant: 8),
            logScrollView.bottomAnchor.constraint(equalTo: downloadButton.topAnchor, constant: -18),
            
            // Buttons
            laterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            laterButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            laterButton.widthAnchor.constraint(equalToConstant: 90),
            laterButton.heightAnchor.constraint(equalToConstant: 28),
            
            downloadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            downloadButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            downloadButton.widthAnchor.constraint(equalToConstant: 130),
            downloadButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func createBadge(text: String, isAccent: Bool) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 4
        badge.layer?.masksToBounds = true
        
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        
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
    
    @objc private func downloadClicked(_ sender: Any) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
        closeSheet()
    }
    
    @objc private func laterClicked(_ sender: Any) {
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
