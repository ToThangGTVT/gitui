// MARK: - UpdateViewController.swift
// A highly-polished custom dialog to notify users of a new update.

import Cocoa

class UpdateViewController: NSViewController {
    
    private let release: GitHubRelease
    private let currentVersion: String
    private var updateTask: Task<Void, Never>?
    private var hasStartedUpdate = false
    private var isUpdating = false
    
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

    deinit {
        updateTask?.cancel()
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
        
        titleLabel.stringValue = "New Update Available"
        notesLabel.stringValue = releaseNotesTitle
        
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 8
        logScrollView.layer?.masksToBounds = true
        logScrollView.layer?.borderWidth = 1
        logScrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        logTextView.textContainer?.containerSize = NSSize(width: logScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        logTextView.textContainer?.widthTracksTextView = true
        
        // Format body text if markdown-like
        let cleanBody = release.body.replacingOccurrences(of: "\r\n", with: "\n")
        logTextView.string = cleanBody.isEmpty ? "gitui \(release.tagName) is ready to download and install." : cleanBody
        downloadButton.title = "Download Now"
        downloadButton.isEnabled = true
        laterButton.title = "Later"
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
        if isUpdating {
            return
        }

        startAutomaticUpdateIfNeeded(forceRestart: true)
    }
    
    @IBAction private func laterClicked(_ sender: Any) {
        updateTask?.cancel()
        updateTask = nil
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

    private var releaseNotesTitle: String {
        let releaseName = release.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleSuffix = releaseName.isEmpty ? release.tagName : releaseName
        return "Release Notes (\(titleSuffix)):"
    }

    private func startAutomaticUpdateIfNeeded(forceRestart: Bool = false) {
        guard !hasStartedUpdate || forceRestart else { return }
        hasStartedUpdate = true
        isUpdating = true

        setUpdatingState(
            title: "Downloading update…",
            detail: "Downloading gitui \(release.tagName) and preparing installation.",
            buttonTitle: "Updating…"
        )

        updateTask = Task { [weak self] in
            guard let self else { return }

            do {
                let preparedUpdate = try await UpdateService.shared.prepareUpdate(for: self.release)

                await MainActor.run {
                    self.setUpdatingState(
                        title: "Installing update…",
                        detail: "Replacing the current app and preparing to relaunch.",
                        buttonTitle: "Installing…"
                    )
                }

                try UpdateService.shared.installPreparedUpdate(preparedUpdate)

                await MainActor.run {
                    self.setUpdatingState(
                        title: "Restarting gitui…",
                        detail: "Finishing the update and relaunching the app.",
                        buttonTitle: "Restarting…"
                    )
                    self.laterButton.isEnabled = false
                }

                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    self.closeSheet()
                    NSApp.terminate(nil)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.updateTask = nil
                    self.isUpdating = false
                    self.hasStartedUpdate = false
                    self.titleLabel.stringValue = "Update paused"
                    self.notesLabel.stringValue = self.releaseNotesTitle
                    self.downloadButton.title = "Resume Update"
                    self.downloadButton.isEnabled = true
                    self.laterButton.title = "Later"
                }
            } catch {
                await MainActor.run {
                    self.updateTask = nil
                    self.presentUpdateFailure(error)
                }
            }
        }
    }

    private func setUpdatingState(title: String, detail: String, buttonTitle: String) {
        titleLabel.stringValue = title
        notesLabel.stringValue = detail
        downloadButton.title = buttonTitle
        downloadButton.isEnabled = false
        laterButton.title = "Cancel"
        laterButton.isEnabled = true
    }

    private func presentUpdateFailure(_ error: Error) {
        isUpdating = false
        hasStartedUpdate = false

        titleLabel.stringValue = "Update failed"
        notesLabel.stringValue = releaseNotesTitle
        downloadButton.title = "Try Again"
        downloadButton.isEnabled = true
        laterButton.title = "Later"
        laterButton.isEnabled = true

        let alert = NSAlert()
        alert.messageText = "Auto-update failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
