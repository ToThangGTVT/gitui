// MARK: - GitFetchViewController.swift

import Cocoa

class GitFetchViewController: NSViewController {

    @IBOutlet weak var allRemotesCheckbox: NSButton!
    @IBOutlet weak var pruneCheckbox: NSButton!
    @IBOutlet weak var tagsCheckbox: NSButton!
    
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var okButton: NSButton!

    @IBOutlet weak var fetchProgressIndicator: NSProgressIndicator!
    
    private let repoPath: String
    private var onFetch: ((_ options: [String]) async throws -> Void)?

    init(repoPath: String, onFetch: @escaping (_ options: [String]) async throws -> Void) {
        self.repoPath = repoPath
        self.onFetch = onFetch
        super.init(nibName: "GitFetchViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(repoPath: String, from window: NSWindow?, onFetch: @escaping (_ options: [String]) async throws -> Void) {
        guard let window = window else { return }
        let vc = GitFetchViewController(repoPath: repoPath, onFetch: onFetch)
        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Fetch"
        sheet.setContentSize(NSSize(width: 420, height: 160))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        allRemotesCheckbox.state = .on
        pruneCheckbox.state = .on
        tagsCheckbox.state = .off
    }

    @IBAction func cancelClicked(_ sender: Any?) {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @IBAction func okClicked(_ sender: Any?) {
        var options: [String] = []
        if allRemotesCheckbox.state == .on {
            options.append("--all")
        }
        if pruneCheckbox.state == .on {
            options.append("--prune")
        }
        if tagsCheckbox.state == .on {
            options.append("--tags")
        }
        
        okButton.isEnabled = false
        cancelButton.isEnabled = false
        fetchProgressIndicator.startAnimation(nil)
        
        Task {
            do {
                if let onFetch = self.onFetch {
                    try await onFetch(options)
                }
                await MainActor.run {
                    self.view.window?.sheetParent?.endSheet(self.view.window!)
                }
            } catch {
                await MainActor.run {
                    self.okButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                    self.fetchProgressIndicator.stopAnimation(nil)
                }
            }
        }
    }
}
