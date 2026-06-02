// MARK: - GitPushProgressViewController.swift

import Cocoa

class GitPushProgressViewController: NSViewController {
    
    private let remote: String
    private let branch: String
    private let repoPath: String
    private let force: Bool
    private let onComplete: (Bool) -> Void
    
    @IBOutlet private weak var headerIcon: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var subtitleLabel: NSTextField!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var logScrollView: NSScrollView!
    @IBOutlet private var logTextView: NSTextView!
    @IBOutlet private weak var actionButton: NSButton!
    
    private var isSuccess = false
    
    init(remote: String, branch: String, force: Bool = false, repoPath: String, onComplete: @escaping (Bool) -> Void) {
        self.remote = remote
        self.branch = branch
        self.force = force
        self.repoPath = repoPath
        self.onComplete = onComplete
        super.init(nibName: "GitPushProgressViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPush()
    }
    
    private func setupUI() {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            headerIcon.image = NSImage(systemSymbolName: "cloud.and.arrow.up.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        }
        headerIcon.contentTintColor = NSColor.controlAccentColor
        
        subtitleLabel.stringValue = "Pushing branch '\(branch)' to '\(remote)'"
        
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 6
        logScrollView.layer?.masksToBounds = true
        logScrollView.layer?.borderWidth = 1
        logScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        logTextView.textContainer?.containerSize = NSSize(width: logScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        logTextView.textContainer?.widthTracksTextView = true
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
                if force {
                    _ = try await GitService.shared.pushForceStreaming(remote: remote, branch: branch, in: repoPath) { [weak self] outputChunk in
                        self?.appendLog(outputChunk)
                    }
                } else {
                    _ = try await GitService.shared.pushStreaming(remote: remote, branch: branch, in: repoPath) { [weak self] outputChunk in
                        self?.appendLog(outputChunk)
                    }
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
    
    @IBAction private func actionButtonClicked(_ sender: Any) {
        closeSheet()
        onComplete(isSuccess)
    }
    
    private func closeSheet() {
        guard let sheetWindow = view.window, let parent = sheetWindow.sheetParent else { return }
        parent.endSheet(sheetWindow)
    }
    
    // Static show method for global convenience
    static func show(remote: String, branch: String, force: Bool = false, repoPath: String, from window: NSWindow? = nil, onComplete: @escaping (Bool) -> Void) {
        let progressVC = GitPushProgressViewController(remote: remote, branch: branch, force: force, repoPath: repoPath, onComplete: onComplete)
        
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
