// MARK: - GitPullViewController.swift

import Cocoa

class GitPullViewController: NSViewController {

    @IBOutlet weak var remoteDropdown: NSPopUpButton!
    @IBOutlet weak var remoteUrlField: NSTextField!
    @IBOutlet weak var branchDropdown: NSPopUpButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var refreshProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var localBranchLabel: NSTextField!
    
    @IBOutlet weak var commitMergedCheckbox: NSButton!
    @IBOutlet weak var includeMessagesCheckbox: NSButton!
    @IBOutlet weak var newCommitCheckbox: NSButton!
    @IBOutlet weak var rebaseCheckbox: NSButton!

    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var okButton: NSButton!

    private var pullProgressIndicator = NSProgressIndicator()

    private let repoPath: String
    private let defaultBranch: String
    private var remotes: [GitRemote] = []
    private var remoteBranches: [GitBranch] = []
    
    private var onPull: ((_ remote: String, _ branch: String, _ options: [String]) async throws -> Void)?

    init(repoPath: String, defaultBranch: String, onPull: @escaping (_ remote: String, _ branch: String, _ options: [String]) async throws -> Void) {
        self.repoPath = repoPath
        self.defaultBranch = defaultBranch
        self.onPull = onPull
        super.init(nibName: "GitPullViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(defaultBranch: String, repoPath: String, from window: NSWindow?, onPull: @escaping (_ remote: String, _ branch: String, _ options: [String]) async throws -> Void) {
        guard let window = window else { return }
        let vc = GitPullViewController(repoPath: repoPath, defaultBranch: defaultBranch, onPull: onPull)
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Pull"
        sheet.setContentSize(NSSize(width: 580, height: 320))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        
        pullProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        pullProgressIndicator.style = .bar
        pullProgressIndicator.isIndeterminate = true
        pullProgressIndicator.isDisplayedWhenStopped = false
        view.addSubview(pullProgressIndicator)
        
        NSLayoutConstraint.activate([
            pullProgressIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pullProgressIndicator.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            pullProgressIndicator.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -20)
        ])
    }

    private func setupUI() {
        refreshProgressIndicator.isDisplayedWhenStopped = false
        localBranchLabel.stringValue = defaultBranch
        commitMergedCheckbox.state = .on // Default checked
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
                        remoteChanged(nil)
                    }
                }
            } catch {
                print("Failed to load remotes/branches: \(error)")
            }
        }
    }

    @IBAction func remoteChanged(_ sender: Any?) {
        guard let selectedRemoteName = remoteDropdown.titleOfSelectedItem else { return }
        if let remote = remotes.first(where: { $0.name == selectedRemoteName }) {
            remoteUrlField.stringValue = remote.url
        }
        
        // Filter branches for this remote
        let prefix = "remotes/\(selectedRemoteName)/"
        let branchesForRemote = remoteBranches.filter { $0.name.hasPrefix(prefix) }
        
        branchDropdown.removeAllItems()
        for branch in branchesForRemote {
            let branchName = branch.name.replacingOccurrences(of: prefix, with: "")
            branchDropdown.addItem(withTitle: branchName)
        }
        
        // Try to select default branch if exists
        if branchDropdown.itemTitles.contains(defaultBranch) {
            branchDropdown.selectItem(withTitle: defaultBranch)
        } else if branchDropdown.numberOfItems > 0 {
            branchDropdown.selectItem(at: 0)
        }
    }

    @IBAction func refreshClicked(_ sender: Any?) {
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
                    self.remoteChanged(nil)
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

    @IBAction func cancelClicked(_ sender: Any?) {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @IBAction func okClicked(_ sender: Any?) {
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
        
        okButton.isEnabled = false
        cancelButton.isEnabled = false
        pullProgressIndicator.startAnimation(nil)
        
        Task {
            do {
                if let onPull = self.onPull {
                    try await onPull(remote, branch, options)
                }
                await MainActor.run {
                    self.view.window?.sheetParent?.endSheet(self.view.window!)
                }
            } catch {
                await MainActor.run {
                    self.okButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                    self.pullProgressIndicator.stopAnimation(nil)
                }
            }
        }
    }
}
