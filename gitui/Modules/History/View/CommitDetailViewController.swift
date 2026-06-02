// MARK: - CommitDetailViewController.swift

import Cocoa

class CommitDetailViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate, NSMenuDelegate {

    // MARK: - IBOutlets
    @IBOutlet private weak var splitView: NSSplitView!
    @IBOutlet private weak var changedFilesTableView: NSTableView!
    @IBOutlet private weak var diffTableView: NSTableView!
    @IBOutlet private weak var diffTitleLabel: NSTextField!

    // MARK: Files pane
    private var changedFiles: [GitFileStatus] = []

    // MARK: Diff pane
    private var diffLines: [DiffLine] = []

    // MARK: State
    private var commitHash = ""
    private var currentLoadTask: Task<Void, Never>? = nil

    // MARK: - Lifecycle

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: "CommitDetailViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        splitView.delegate = self
        
        changedFilesTableView.dataSource = self
        changedFilesTableView.delegate = self
        
        let menu = NSMenu()
        menu.delegate = self
        changedFilesTableView.menu = menu
        
        diffTableView.dataSource = self
        diffTableView.delegate = self
        diffTableView.allowsMultipleSelection = true
        diffTableView.selectionHighlightStyle = .regular
    }

    // MARK: - Public

    func configure(with commit: CommitNode) {
        commitHash = commit.hash
        diffLines = []
        diffTableView.reloadData()
        diffTitleLabel.stringValue = "Select a file to view diff"
        changedFilesTableView.deselectAll(nil)
        loadFilesChanged(for: commit.hash)
    }

    // MARK: - Data loading

    private func loadFilesChanged(for hash: String) {
        guard let path = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        Task {
            do {
                let output = try await GitService.shared.runGit(
                    ["show", "--name-status", "--pretty=format:", hash], in: path)
                var files: [GitFileStatus] = []
                for line in output.components(separatedBy: .newlines) {
                    let parts = line.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        files.append(GitFileStatus(path: parts[1], status: parts[0], isStaged: false))
                    }
                }
                await MainActor.run {
                    self.changedFiles = files
                    self.changedFilesTableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.changedFiles = []
                    self.changedFilesTableView.reloadData()
                }
            }
        }
    }

    private func loadDiff(for file: GitFileStatus) {
        guard let path = RepositoryStore.shared.getActiveRepositoryPath(),
              !commitHash.isEmpty else { return }
        let hash = commitHash
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            do {
                let diff = try await GitService.shared.getCommitFileDiff(
                    hash: hash, file: file.path, in: path)
                guard !Task.isCancelled else { return }
                let hunks = parseDiffHunks(from: diff)
                let lines = buildDiffLines(from: diff, hunks: hunks)
                await MainActor.run {
                    self.diffLines = lines
                    self.diffTitleLabel.stringValue = file.path
                    self.diffTableView.reloadData()
                    if !lines.isEmpty { self.diffTableView.scrollRowToVisible(0) }
                }
            } catch {
                await MainActor.run {
                    self.diffLines = []
                    self.diffTitleLabel.stringValue = file.path
                    self.diffTableView.reloadData()
                }
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === changedFilesTableView { return changedFiles.count }
        if tableView === diffTableView         { return diffLines.count }
        return 0
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView === diffTableView {
            guard row < diffLines.count else { return 18 }
            if case .hunkHeader = diffLines[row].kind { return 26 }
            return 18
        }
        return tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard tableView === diffTableView else { return nil }
        let id = NSUserInterfaceItemIdentifier("DiffRowView")
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NoHighlightRowView {
            return existing
        }
        let rowView = NoHighlightRowView()
        rowView.identifier = id
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        tableView === diffTableView ? diffCellView(for: row) : fileCellView(for: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView,
              table === changedFilesTableView else { return }
        let row = table.selectedRow
        guard row >= 0 && row < changedFiles.count else { return }
        loadDiff(for: changedFiles[row])
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = changedFilesTableView.clickedRow
        guard row >= 0 && row < changedFiles.count else { return }
        
        if row != changedFilesTableView.selectedRow {
            changedFilesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        
        let file = changedFiles[row]
        let blameItem = NSMenuItem(title: "Git Blame: \(file.path)", action: #selector(showBlame), keyEquivalent: "")
        blameItem.target = self
        menu.addItem(blameItem)
    }
    
    @objc private func showBlame() {
        let row = changedFilesTableView.selectedRow
        guard row >= 0 && row < changedFiles.count else { return }
        let file = changedFiles[row]
        
        let blameVC = BlameModule.build(filePath: file.path, commitHash: self.commitHash)
        // Configure frame
        blameVC.view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        
        // Present as modal window
        let window = NSWindow(contentViewController: blameVC)
        window.title = "Git Blame: \(file.path)"
        window.styleMask = [.titled, .closable, .resizable]
        
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
    }

    @objc func copy(_ sender: Any?) {
        guard let window = view.window, window.firstResponder == diffTableView else {
            // Forward to the next responder or let the system handle it if we are not the target
            if let next = self.nextResponder {
                next.tryToPerform(#selector(copy(_:)), with: sender)
            }
            return
        }
        
        let selectedRows = diffTableView.selectedRowIndexes
        guard !selectedRows.isEmpty else { return }
        
        var copiedText = ""
        for row in selectedRows {
            guard row < diffLines.count else { continue }
            let line = diffLines[row]
            switch line.kind {
            case .context, .added, .removed:
                copiedText += (line.rawText.isEmpty ? "" : String(line.rawText.dropFirst())) + "\n"
            case .fileHeader, .hunkHeader:
                break
            }
        }
        
        if !copiedText.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(copiedText, forType: .string)
        }
    }

    // MARK: - Cell builders

    private func fileCellView(for row: Int) -> NSView? {
        guard row < changedFiles.count else { return nil }
        let file = changedFiles[row]
        let id = NSUserInterfaceItemIdentifier("commitFileCell")
        guard let cell = changedFilesTableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView else { return nil }

        cell.textField?.stringValue = file.path

        if let badge = cell.subviews.first(where: { !($0 is NSTextField) }),
           let text = badge.subviews.first as? NSTextField {
            text.stringValue = file.status
            switch file.status {
            case "A":
                text.textColor = .gitFlowStagedAddText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor
            case "D":
                text.textColor = .gitFlowStagedDeleteText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor
            case "M":
                text.textColor = .gitFlowModifiedText
                badge.layer?.backgroundColor = NSColor.gitFlowModified.cgColor
            default:
                text.textColor = .gitFlowAccent
                badge.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
            }
        }

        return cell
    }

    private func diffCellView(for row: Int) -> NSView? {
        guard row < diffLines.count else { return nil }
        let line = diffLines[row]

        if case .hunkHeader(let hunk) = line.kind {
            let id = NSUserInterfaceItemIdentifier("commitHunkCell")
            var cell = diffTableView.makeView(withIdentifier: id, owner: self) as? HunkHeaderCellView
            if cell == nil { cell = HunkHeaderCellView(); cell?.identifier = id }
            cell?.configure(headerText: line.rawText, isUnstagedDiff: false, isReadOnly: true)
            return cell
        }

        let id = NSUserInterfaceItemIdentifier("commitDiffLineCell")
        var cell = diffTableView.makeView(withIdentifier: id, owner: self) as? DiffLineCellView
        if cell == nil { cell = DiffLineCellView(); cell?.identifier = id }
        cell?.configure(with: line)
        return cell
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        index == 0 ? 80 : proposed
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMaxCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        index == 0 ? splitView.bounds.height - 100 : proposed
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
}
