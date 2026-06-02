// MARK: - CloneViewController.swift

import Cocoa

class CloneViewController: NSViewController {

    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var destField: NSTextField!
    @IBOutlet private weak var browseButton: NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var cloneButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var statusLabel: NSTextField!

    private var onCloned: ((String) -> Void)?

    static func show(from window: NSWindow, onCloned: @escaping (String) -> Void) {
        let vc = CloneViewController(nibName: "CloneViewController", bundle: nil)
        vc.onCloned = onCloned
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Clone Repository"
        sheet.setContentSize(NSSize(width: 460, height: 200))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // XIB provides the UI, so no buildUI needed.
    }

    @IBAction private func browseClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if result == .OK, let url = panel.url {
                let repoName = self?.suggestedName() ?? "repo"
                self?.destField.stringValue = url.appendingPathComponent(repoName).path
            }
        }
    }

    private func suggestedName() -> String {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        return URL(string: url)?.deletingPathExtension().lastPathComponent ?? "repo"
    }

    @IBAction private func cancelClicked(_ sender: Any) {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @IBAction private func cloneClicked(_ sender: Any) {
        let repoURL = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        let dest    = destField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !repoURL.isEmpty && !dest.isEmpty else {
            statusLabel.stringValue = "Please fill in both fields."
            statusLabel.textColor = .systemRed
            return
        }

        cloneButton.isEnabled = false
        cancelButton.isEnabled = false
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = "Cloning…"
        statusLabel.textColor = .secondaryLabelColor

        Task {
            do {
                try await GitService.shared.clone(url: repoURL, to: dest)
                await MainActor.run {
                    self.progressIndicator.stopAnimation(nil)
                    self.view.window?.sheetParent?.endSheet(self.view.window!)
                    self.onCloned?(dest)
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimation(nil)
                    self.statusLabel.stringValue = error.localizedDescription
                    self.statusLabel.textColor = .systemRed
                    self.cloneButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                }
            }
        }
    }
}
