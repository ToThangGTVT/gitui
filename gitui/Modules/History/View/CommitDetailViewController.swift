// MARK: - CommitDetailViewController.swift

import Cocoa

class CommitDetailViewController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate {

    // MARK: Files pane
    private var changedFilesTableView = NSTableView()
    private var changedFiles: [GitFileStatus] = []

    // MARK: Diff pane
    private var diffTableView  = NSTableView()
    private var diffTitleLabel = NSTextField(labelWithString: "Select a file to view diff")
    private var diffLines: [DiffLine] = []

    // MARK: State
    private var commitHash = ""
    private var currentLoadTask: Task<Void, Never>? = nil

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let splitView = NSSplitView()
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let filesPane = buildFilesPane()
        filesPane.frame = NSRect(x: 0, y: 0, width: 260, height: 140)
        splitView.addArrangedSubview(filesPane)

        let diffPane = buildDiffPane()
        diffPane.frame = NSRect(x: 0, y: 0, width: 260, height: 260)
        splitView.addArrangedSubview(diffPane)
    }

    private func buildFilesPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = true
        pane.autoresizingMask = [.width, .height]

        let titleBar = NSView()
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6).cgColor
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: "CHANGED FILES")
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleLabel)

        let titleBorder = NSView()
        titleBorder.wantsLayer = true
        titleBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        titleBorder.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleBorder)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(scroll)

        changedFilesTableView.headerView = nil
        changedFilesTableView.backgroundColor = NSColor.controlBackgroundColor
        changedFilesTableView.gridColor = NSColor.separatorColor
        changedFilesTableView.gridStyleMask = .solidHorizontalGridLineMask
        changedFilesTableView.rowHeight = 24
        changedFilesTableView.allowsMultipleSelection = false
        changedFilesTableView.dataSource = self
        changedFilesTableView.delegate = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fileCol"))
        col.resizingMask = .autoresizingMask
        changedFilesTableView.addTableColumn(col)
        changedFilesTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        scroll.documentView = changedFilesTableView

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: pane.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 12),

            titleBorder.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor),
            titleBorder.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor),
            titleBorder.bottomAnchor.constraint(equalTo: titleBar.bottomAnchor),
            titleBorder.heightAnchor.constraint(equalToConstant: 1),

            scroll.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
        ])

        return pane
    }

    private func buildDiffPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = true
        pane.autoresizingMask = [.width, .height]
        pane.wantsLayer = true
        pane.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let topBorder = NSView()
        topBorder.wantsLayer = true
        topBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(topBorder)

        diffTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        diffTitleLabel.textColor = .secondaryLabelColor
        diffTitleLabel.lineBreakMode = .byTruncatingMiddle
        diffTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(diffTitleLabel)

        let titleBorder = NSView()
        titleBorder.wantsLayer = true
        titleBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        titleBorder.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(titleBorder)

        let diffScroll = NSScrollView()
        diffScroll.hasVerticalScroller = true
        diffScroll.hasHorizontalScroller = true
        diffScroll.autohidesScrollers = true
        diffScroll.borderType = .noBorder
        diffScroll.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(diffScroll)

        diffTableView.headerView = nil
        diffTableView.backgroundColor = NSColor.controlBackgroundColor
        diffTableView.rowHeight = 18
        diffTableView.gridStyleMask = []
        diffTableView.intercellSpacing = NSSize(width: 0, height: 0)
        diffTableView.selectionHighlightStyle = .none
        diffTableView.usesAlternatingRowBackgroundColors = false
        diffTableView.dataSource = self
        diffTableView.delegate = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("diffCol"))
        col.resizingMask = .autoresizingMask
        diffTableView.addTableColumn(col)
        diffTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        diffScroll.documentView = diffTableView

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: pane.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            diffTitleLabel.topAnchor.constraint(equalTo: topBorder.bottomAnchor, constant: 6),
            diffTitleLabel.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 12),
            diffTitleLabel.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -12),

            titleBorder.topAnchor.constraint(equalTo: diffTitleLabel.bottomAnchor, constant: 6),
            titleBorder.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            titleBorder.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            titleBorder.heightAnchor.constraint(equalToConstant: 1),

            diffScroll.topAnchor.constraint(equalTo: titleBorder.bottomAnchor),
            diffScroll.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            diffScroll.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            diffScroll.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
        ])

        return pane
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

    // MARK: - Cell builders

    private func fileCellView(for row: Int) -> NSView? {
        guard row < changedFiles.count else { return nil }
        let file = changedFiles[row]
        let id = NSUserInterfaceItemIdentifier("commitFileCell")
        var cell = changedFilesTableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = id

            let badge = NSView()
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 3
            badge.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(badge)

            let badgeText = NSTextField(labelWithString: "")
            badgeText.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            badgeText.alignment = .center
            badgeText.translatesAutoresizingMaskIntoConstraints = false
            badge.addSubview(badgeText)

            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 11)
            label.lineBreakMode = .byTruncatingMiddle
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label

            NSLayoutConstraint.activate([
                badge.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                badge.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: 22),
                badge.heightAnchor.constraint(equalToConstant: 16),
                badgeText.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 2),
                badgeText.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -2),
                badgeText.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 7),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }

        cell?.textField?.stringValue = file.path

        if let badge = cell?.subviews.first(where: { !($0 is NSTextField) }),
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
