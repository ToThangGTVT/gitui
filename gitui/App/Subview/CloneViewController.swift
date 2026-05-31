// MARK: - CloneViewController.swift

import Cocoa

class CloneViewController: NSViewController {

    private var urlField      = NSTextField()
    private var destField     = NSTextField()
    private var browseButton  = NSButton(title: "Browse…", target: nil, action: nil)
    private var progressIndicator = NSProgressIndicator()
    private var cloneButton   = NSButton()
    private var cancelButton  = NSButton()
    private var statusLabel   = NSTextField(labelWithString: "")

    private var onCloned: ((String) -> Void)?

    static func show(from window: NSWindow, onCloned: @escaping (String) -> Void) {
        let vc = CloneViewController()
        vc.onCloned = onCloned
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Clone Repository"
        sheet.setContentSize(NSSize(width: 460, height: 200))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        func sectionLabel(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = NSFont.systemFont(ofSize: 12)
            l.alignment = .right
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }

        let urlLabel  = sectionLabel("Repository URL:")
        let destLabel = sectionLabel("Destination:")

        urlField.placeholderString  = "https://github.com/user/repo.git"
        destField.placeholderString = "/Users/you/Projects/repo"
        for f in [urlField, destField] {
            f.font = NSFont.systemFont(ofSize: 12)
            f.translatesAutoresizingMaskIntoConstraints = false
        }

        browseButton.target = self
        browseButton.action = #selector(browseClicked)
        browseButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .push
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        cloneButton.title = "Clone"
        cloneButton.bezelStyle = .push
        cloneButton.keyEquivalent = "\r"
        cloneButton.target = self
        cloneButton.action = #selector(cloneClicked)
        cloneButton.translatesAutoresizingMaskIntoConstraints = false

        let sep = NSBox(); sep.boxType = .separator; sep.translatesAutoresizingMaskIntoConstraints = false

        for v in [urlLabel, urlField, destLabel, destField, browseButton,
                  statusLabel, progressIndicator, sep, cancelButton, cloneButton] {
            view.addSubview(v as! NSView)
        }

        NSLayoutConstraint.activate([
            urlLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            urlLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlLabel.widthAnchor.constraint(equalToConstant: 120),

            urlField.centerYAnchor.constraint(equalTo: urlLabel.centerYAnchor),
            urlField.leadingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 8),
            urlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            destLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 14),
            destLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            destLabel.widthAnchor.constraint(equalToConstant: 120),

            destField.centerYAnchor.constraint(equalTo: destLabel.centerYAnchor),
            destField.leadingAnchor.constraint(equalTo: destLabel.trailingAnchor, constant: 8),
            destField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -8),

            browseButton.centerYAnchor.constraint(equalTo: destLabel.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            browseButton.widthAnchor.constraint(equalToConstant: 80),

            statusLabel.topAnchor.constraint(equalTo: destLabel.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: progressIndicator.leadingAnchor, constant: -8),

            progressIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            sep.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cancelButton.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 10),
            cancelButton.trailingAnchor.constraint(equalTo: cloneButton.leadingAnchor, constant: -8),

            cloneButton.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 10),
            cloneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cloneButton.widthAnchor.constraint(equalToConstant: 70),
        ])
    }

    @objc private func browseClicked() {
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

    @objc private func cancelClicked() {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @objc private func cloneClicked() {
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
