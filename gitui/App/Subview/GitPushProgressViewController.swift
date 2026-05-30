// MARK: - GitPushProgressViewController.swift

import Cocoa

class GitPushProgressViewController: NSViewController {
    
    private let remote: String
    private let branch: String
    private let repoPath: String
    private let onComplete: (Bool) -> Void
    
    // UI Outlets
    private var headerIcon: NSImageView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var progressIndicator: NSProgressIndicator!
    private var logScrollView: NSScrollView!
    private var logTextView: NSTextView!
    private var actionButton: NSButton!
    
    private var isSuccess = false
    
    init(remote: String, branch: String, repoPath: String, onComplete: @escaping (Bool) -> Void) {
        self.remote = remote
        self.branch = branch
        self.repoPath = repoPath
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Setup base container view
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPush()
    }
    
    private func setupUI() {
        // 1. Icon ImageView
        headerIcon = NSImageView()
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.imageScaling = .scaleProportionallyUpOrDown
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            headerIcon.image = NSImage(systemSymbolName: "cloud.and.arrow.up.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        headerIcon.contentTintColor = NSColor.controlAccentColor
        view.addSubview(headerIcon)
        
        // 2. Title Label
        titleLabel = NSTextField(labelWithString: "Pushing to Remote...")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        view.addSubview(titleLabel)
        
        // 3. Subtitle Label (Badge info)
        subtitleLabel = NSTextField(labelWithString: "Pushing branch '\(branch)' to '\(remote)'")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(subtitleLabel)
        
        // 4. Horizontal Indeterminate Progress Indicator (Bar style)
        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.controlSize = .regular
        view.addSubview(progressIndicator)
        
        // 5. Scroll View for Terminal Logs
        logScrollView = NSScrollView()
        logScrollView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.hasVerticalScroller = true
        logScrollView.hasHorizontalScroller = false
        logScrollView.autohidesScrollers = true
        logScrollView.borderType = .noBorder
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 6
        logScrollView.layer?.masksToBounds = true
        logScrollView.layer?.borderWidth = 1
        logScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        logScrollView.drawsBackground = true
        logScrollView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        view.addSubview(logScrollView)
        
        // 6. Text View for Terminal Logs
        logTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 510, height: 200))
        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.autoresizingMask = [.width]
        logTextView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        logTextView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.textContainer?.containerSize = NSSize(width: 510, height: CGFloat.greatestFiniteMagnitude)
        logTextView.textContainer?.widthTracksTextView = true
        logScrollView.documentView = logTextView
        
        // 7. Action / Close Button
        actionButton = NSButton(title: "Pushing...", target: self, action: #selector(actionButtonClicked(_:)))
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .rounded
        actionButton.isEnabled = false
        view.addSubview(actionButton)
        
        // Autolayout constraints
        NSLayoutConstraint.activate([
            // Icon
            headerIcon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerIcon.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            headerIcon.widthAnchor.constraint(equalToConstant: 28),
            headerIcon.heightAnchor.constraint(equalToConstant: 28),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Indeterminate Progress Bar
            progressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            // Scrollview for Logs
            logScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logScrollView.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 12),
            logScrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16),
            
            // Action Button
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            actionButton.widthAnchor.constraint(equalToConstant: 100),
            actionButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func appendLog(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentText = self.logTextView.string
            self.logTextView.string = currentText + text
            
            // Scroll to the end of the text view
            self.logTextView.scrollRangeToVisible(NSRange(location: self.logTextView.string.count, length: 0))
        }
    }
    
    private func startPush() {
        progressIndicator.startAnimation(nil)
        appendLog("Connecting to remote '\(remote)'...\n")
        
        Task {
            do {
                _ = try await GitService.shared.pushStreaming(remote: remote, branch: branch, in: repoPath) { [weak self] outputChunk in
                    self?.appendLog(outputChunk)
                }
                
                await MainActor.run {
                    self.isSuccess = true
                    self.updateUIForCompleted(success: true, errorMessage: nil)
                }
            } catch {
                await MainActor.run {
                    self.isSuccess = false
                    self.updateUIForCompleted(success: false, errorMessage: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateUIForCompleted(success: Bool, errorMessage: String?) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        
        if success {
            titleLabel.stringValue = "Push Completed Successfully"
            titleLabel.textColor = NSColor.systemGreen
            headerIcon.contentTintColor = NSColor.systemGreen
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .bold)
                headerIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
            }
            appendLog("\n[SUCCESS] Successfully pushed \(branch) to remote \(remote).\n")
            actionButton.title = "Done"
        } else {
            titleLabel.stringValue = "Push Failed"
            titleLabel.textColor = NSColor.systemRed
            headerIcon.contentTintColor = NSColor.systemRed
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .bold)
                headerIcon.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
            }
            if let errorMsg = errorMessage {
                appendLog("\n[ERROR] \(errorMsg)\n")
            }
            actionButton.title = "Close"
        }
        
        actionButton.isEnabled = true
    }
    
    @objc private func actionButtonClicked(_ sender: Any) {
        closeSheet()
        onComplete(isSuccess)
    }
    
    private func closeSheet() {
        guard let sheetWindow = view.window, let parent = sheetWindow.sheetParent else { return }
        parent.endSheet(sheetWindow)
    }
    
    // Static show method for global convenience
    static func show(remote: String, branch: String, repoPath: String, from window: NSWindow? = nil, onComplete: @escaping (Bool) -> Void) {
        let progressVC = GitPushProgressViewController(remote: remote, branch: branch, repoPath: repoPath, onComplete: onComplete)
        
        let progressWindow = NSWindow(contentViewController: progressVC)
        progressWindow.styleMask = [.titled, .closable]
        progressWindow.title = "Git Push"
        progressWindow.setContentSize(NSSize(width: 550, height: 380))
        
        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
        if let targetWindow = targetWindow {
            targetWindow.beginSheet(progressWindow, completionHandler: nil)
        }
    }
}
