// MARK: - GitPullViewController.swift

import Cocoa

class GitPullViewController: NSViewController {

    private var remoteDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
    private var remoteUrlField = NSTextField(labelWithString: "")
    private var branchDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
    private var refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private var refreshProgressIndicator = NSProgressIndicator()
    private var localBranchLabel = NSTextField(labelWithString: "")
    
    private var commitMergedCheckbox = NSButton(checkboxWithTitle: "Commit merged changes immediately", target: nil, action: nil)
    private var includeMessagesCheckbox = NSButton(checkboxWithTitle: "Include messages from commits being merged in merge commit", target: nil, action: nil)
    private var newCommitCheckbox = NSButton(checkboxWithTitle: "Create new commit even if fast-forward merge", target: nil, action: nil)
    private var rebaseCheckbox = NSButton(checkboxWithTitle: "Rebase instead of merge (WARNING: make sure you haven't pushed your changes)", target: nil, action: nil)

    private var cancelButton = NSButton()
    private var okButton = NSButton()

    private let repoPath: String
    private let defaultBranch: String
    private var remotes: [GitRemote] = []
    private var remoteBranches: [GitBranch] = []
    
    private var onPull: ((_ remote: String, _ branch: String, _ options: [String]) -> Void)?

    init(repoPath: String, defaultBranch: String, onPull: @escaping (_ remote: String, _ branch: String, _ options: [String]) -> Void) {
        self.repoPath = repoPath
        self.defaultBranch = defaultBranch
        self.onPull = onPull
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(defaultBranch: String, repoPath: String, from window: NSWindow?, onPull: @escaping (_ remote: String, _ branch: String, _ options: [String]) -> Void) {
        guard let window = window else { return }
        let vc = GitPullViewController(repoPath: repoPath, defaultBranch: defaultBranch, onPull: onPull)
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Pull"
        sheet.setContentSize(NSSize(width: 580, height: 320))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 320))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        let labelFont = NSFont.systemFont(ofSize: 13)
        let controlFont = NSFont.systemFont(ofSize: 13)
        let smallFont = NSFont.systemFont(ofSize: 11)

        func makeLabel(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = labelFont
            l.alignment = .right
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }

        let l1 = makeLabel("Pull from repository:")
        let l2 = makeLabel("Remote branch to pull:")
        let l3 = makeLabel("Pull into local branch:")

        remoteDropdown.translatesAutoresizingMaskIntoConstraints = false
        remoteDropdown.font = controlFont
        remoteDropdown.target = self
        remoteDropdown.action = #selector(remoteChanged)

        remoteUrlField.translatesAutoresizingMaskIntoConstraints = false
        remoteUrlField.font = smallFont
        remoteUrlField.textColor = .disabledControlTextColor
        remoteUrlField.lineBreakMode = .byTruncatingTail

        branchDropdown.translatesAutoresizingMaskIntoConstraints = false
        branchDropdown.font = controlFont

        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded
        refreshButton.font = controlFont
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)

        refreshProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        refreshProgressIndicator.style = .spinning
        refreshProgressIndicator.controlSize = .small
        refreshProgressIndicator.isDisplayedWhenStopped = false

        localBranchLabel.translatesAutoresizingMaskIntoConstraints = false
        localBranchLabel.font = controlFont
        localBranchLabel.stringValue = defaultBranch

        // Checkboxes
        commitMergedCheckbox.translatesAutoresizingMaskIntoConstraints = false
        commitMergedCheckbox.font = controlFont
        commitMergedCheckbox.state = .on // Default checked

        includeMessagesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        includeMessagesCheckbox.font = controlFont

        newCommitCheckbox.translatesAutoresizingMaskIntoConstraints = false
        newCommitCheckbox.font = controlFont

        rebaseCheckbox.translatesAutoresizingMaskIntoConstraints = false
        rebaseCheckbox.font = controlFont

        // Options Box
        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.title = "Options"
        box.titleFont = smallFont
        
        let stackView = NSStackView(views: [commitMergedCheckbox, includeMessagesCheckbox, newCommitCheckbox, rebaseCheckbox])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: box.contentView!.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor, constant: -12)
        ])

        // Buttons
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)

        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.controlSize = .large
        okButton.target = self
        okButton.action = #selector(okClicked)

        let views = [l1, l2, l3, remoteDropdown, remoteUrlField, branchDropdown, refreshButton, refreshProgressIndicator, localBranchLabel, box, cancelButton, okButton]
        for v in views {
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            l1.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            l1.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            l1.widthAnchor.constraint(equalToConstant: 160),

            remoteDropdown.centerYAnchor.constraint(equalTo: l1.centerYAnchor),
            remoteDropdown.leadingAnchor.constraint(equalTo: l1.trailingAnchor, constant: 8),
            remoteDropdown.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            remoteUrlField.topAnchor.constraint(equalTo: remoteDropdown.bottomAnchor, constant: 4),
            remoteUrlField.leadingAnchor.constraint(equalTo: remoteDropdown.leadingAnchor),
            remoteUrlField.trailingAnchor.constraint(equalTo: remoteDropdown.trailingAnchor),

            l2.topAnchor.constraint(equalTo: remoteUrlField.bottomAnchor, constant: 12),
            l2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            l2.widthAnchor.constraint(equalToConstant: 160),

            branchDropdown.centerYAnchor.constraint(equalTo: l2.centerYAnchor),
            branchDropdown.leadingAnchor.constraint(equalTo: l2.trailingAnchor, constant: 8),
            
            refreshButton.centerYAnchor.constraint(equalTo: branchDropdown.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: branchDropdown.trailingAnchor, constant: 8),
            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            branchDropdown.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            
            refreshProgressIndicator.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            refreshProgressIndicator.centerXAnchor.constraint(equalTo: refreshButton.centerXAnchor),

            l3.topAnchor.constraint(equalTo: l2.bottomAnchor, constant: 16),
            l3.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            l3.widthAnchor.constraint(equalToConstant: 160),

            localBranchLabel.centerYAnchor.constraint(equalTo: l3.centerYAnchor),
            localBranchLabel.leadingAnchor.constraint(equalTo: l3.trailingAnchor, constant: 12),

            box.topAnchor.constraint(equalTo: l3.bottomAnchor, constant: 20),
            box.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            box.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            okButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            okButton.widthAnchor.constraint(equalToConstant: 80),

            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor)
        ])
    }

    private func loadData() {
        Task {
            do {
                remotes = try await GitService.shared.getRemotes(in: repoPath)
                let branches = try await GitService.shared.getBranches(in: repoPath)
                self.remoteBranches = branches.filter { $0.isRemote }
                
                await MainActor.run {
                    remoteDropdown.removeAllItems()
                    for remote in remotes {
                        remoteDropdown.addItem(withTitle: remote.name)
                    }
                    if !remotes.isEmpty {
                        remoteDropdown.selectItem(at: 0)
                        remoteChanged()
                    }
                }
            } catch {
                print("Failed to load remotes/branches: \(error)")
            }
        }
    }

    @objc private func remoteChanged() {
        guard let selectedRemoteName = remoteDropdown.titleOfSelectedItem else { return }
        if let remote = remotes.first(where: { $0.name == selectedRemoteName }) {
            remoteUrlField.stringValue = remote.url
        }
        
        // Filter branches for this remote
        let prefix = "remotes/\(selectedRemoteName)/"
        let branchesForRemote = remoteBranches.filter { $0.name.hasPrefix(prefix) }
        
        branchDropdown.removeAllItems()
        for branch in branchesForRemote {
            branchDropdown.addItem(withTitle: branch.shortName)
        }
        
        // Try to select default branch if exists
        if branchDropdown.itemTitles.contains(defaultBranch) {
            branchDropdown.selectItem(withTitle: defaultBranch)
        } else if branchDropdown.numberOfItems > 0 {
            branchDropdown.selectItem(at: 0)
        }
    }

    @objc private func refreshClicked() {
        guard let selectedRemoteName = remoteDropdown.titleOfSelectedItem else { return }
        refreshButton.isEnabled = false
        refreshButton.title = ""
        refreshProgressIndicator.startAnimation(nil)
        Task {
            do {
                try await GitService.shared.fetch(remote: selectedRemoteName, in: repoPath)
                let branches = try await GitService.shared.getBranches(in: repoPath)
                self.remoteBranches = branches.filter { $0.isRemote }
                await MainActor.run {
                    self.remoteChanged()
                    self.refreshButton.isEnabled = true
                    self.refreshButton.title = "Refresh"
                    self.refreshProgressIndicator.stopAnimation(nil)
                }
            } catch {
                await MainActor.run {
                    self.refreshButton.isEnabled = true
                    self.refreshButton.title = "Refresh"
                    self.refreshProgressIndicator.stopAnimation(nil)
                }
            }
        }
    }

    @objc private func cancelClicked() {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @objc private func okClicked() {
        guard let remote = remoteDropdown.titleOfSelectedItem,
              let branch = branchDropdown.titleOfSelectedItem else { return }
              
        var options: [String] = []
        if commitMergedCheckbox.state == .off {
            options.append("--no-commit")
        }
        if includeMessagesCheckbox.state == .on {
            options.append("--log")
        }
        if newCommitCheckbox.state == .on {
            options.append("--no-ff")
        }
        if rebaseCheckbox.state == .on {
            options.append("--rebase")
        }
        
        view.window?.sheetParent?.endSheet(view.window!)
        onPull?(remote, branch, options)
    }
}
