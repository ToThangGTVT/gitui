// MARK: - HistoryViewController.swift

import Cocoa

protocol HistoryViewProtocol: AnyObject {
    func showHistory(_ commits: [CommitNode])
    func updateCommitDetails(_ commit: CommitNode)
    func showLoading(_ loading: Bool)
}

class HistoryViewController: NSViewController, HistoryViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSSplitViewDelegate {
    
    var presenter: HistoryPresenterProtocol?
    
    private var commits: [CommitNode] = []
    private var maxLaneCount: Int = 1
    private var parentHashes: Set<String> = []
    
    // UI Elements
    private var splitView: NSSplitView!
    private var leftContainer: NSView!
    private var rightContainer: NSView!
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var progressIndicator: NSProgressIndicator!

    // Commit info panel (bottom of left pane)
    private var infoPanel: NSView!
    private var infoAvatarView: AvatarView!
    private var infoAuthorLabel: NSTextField!
    private var infoDateLabel: NSTextField!
    private var infoHashLabel: NSTextField!
    private var infoMessageView: NSTextView!

    // Split view persistence
    private var splitPersistence: SplitViewPersistence?

    // Child View Controller
    private let detailVC = CommitDetailViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private var hasRestoredSplit = false
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if !hasRestoredSplit && splitView.bounds.width > 200 {
            splitPersistence?.restoreDividerPositions()
            hasRestoredSplit = true
        }
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Vertical NSSplitView
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)
        
        // Wire persistence (sets autosaveName + identifier internally)
        splitPersistence = SplitViewPersistence(splitView: splitView, key: "gitflow.split.history")
        
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Left pane (min width 400px)
        leftContainer = NSView()
        leftContainer.translatesAutoresizingMaskIntoConstraints = true
        leftContainer.autoresizingMask = [.width, .height]
        
        // Right pane (min width 260px)
        rightContainer = NSView()
        rightContainer.translatesAutoresizingMaskIntoConstraints = true
        rightContainer.autoresizingMask = [.width, .height]
        
        splitView.addArrangedSubview(leftContainer)
        splitView.addArrangedSubview(rightContainer)
        
        // Set default divider position only if no saved position exists
        if UserDefaults.standard.array(forKey: "gitflow.split.history") == nil {
            splitView.setPosition(680, ofDividerAt: 0)
        }
        
        // 2. Left Pane UI: NSScrollView + NSTableView + Info Panel
        infoPanel = buildInfoPanel()
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(infoPanel)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Info panel pinned to bottom
            infoPanel.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            infoPanel.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            infoPanel.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),
            infoPanel.heightAnchor.constraint(equalToConstant: 130),

            // Graph fills the rest above info panel
            scrollView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: infoPanel.topAnchor),
        ])
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.gridColor = NSColor.separatorColor
        tableView.gridStyleMask = []
        tableView.rowHeight = 28 // GraphMetrics.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsMultipleSelection = false
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commitColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        
        // Setup table view context menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        
        // Setup bounds changed notification for infinite scrolling
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        // 3. Right Pane UI: Embed CommitDetailViewController
        addChild(detailVC)
        detailVC.view.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(detailVC.view)
        
        NSLayoutConstraint.activate([
            detailVC.view.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            detailVC.view.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
            detailVC.view.topAnchor.constraint(equalTo: rightContainer.topAnchor),
            detailVC.view.bottomAnchor.constraint(equalTo: rightContainer.bottomAnchor)
        ])
        
        // 4. Loading Indicator (top-right overlay on the left pane)
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: -16),
            progressIndicator.topAnchor.constraint(equalTo: leftContainer.topAnchor, constant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func buildInfoPanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let topBorder = NSView()
        topBorder.wantsLayer = true
        topBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(topBorder)

        infoAvatarView = AvatarView()
        infoAvatarView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(infoAvatarView)

        infoHashLabel = NSTextField(labelWithString: "")
        infoHashLabel.font = NSFont(name: "Menlo", size: 10) ?? NSFont.userFixedPitchFont(ofSize: 10)
        infoHashLabel.textColor = .secondaryLabelColor
        infoHashLabel.wantsLayer = true
        infoHashLabel.layer?.cornerRadius = 3
        infoHashLabel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        infoHashLabel.alignment = .center
        infoHashLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(infoHashLabel)

        infoAuthorLabel = NSTextField(labelWithString: "")
        infoAuthorLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        infoAuthorLabel.textColor = .labelColor
        infoAuthorLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(infoAuthorLabel)

        infoDateLabel = NSTextField(labelWithString: "")
        infoDateLabel.font = NSFont.systemFont(ofSize: 11)
        infoDateLabel.textColor = .secondaryLabelColor
        infoDateLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(infoDateLabel)

        let msgScroll = NSScrollView()
        msgScroll.hasVerticalScroller = false
        msgScroll.borderType = .noBorder
        msgScroll.drawsBackground = false
        msgScroll.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(msgScroll)

        infoMessageView = NSTextView()
        infoMessageView.isRichText = false
        infoMessageView.isEditable = false
        infoMessageView.font = NSFont.systemFont(ofSize: 11)
        infoMessageView.textColor = .labelColor
        infoMessageView.backgroundColor = .clear
        msgScroll.documentView = infoMessageView

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: panel.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            infoAvatarView.topAnchor.constraint(equalTo: topBorder.bottomAnchor, constant: 10),
            infoAvatarView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            infoAvatarView.widthAnchor.constraint(equalToConstant: 30),
            infoAvatarView.heightAnchor.constraint(equalToConstant: 30),

            infoAuthorLabel.topAnchor.constraint(equalTo: infoAvatarView.topAnchor),
            infoAuthorLabel.leadingAnchor.constraint(equalTo: infoAvatarView.trailingAnchor, constant: 8),

            infoHashLabel.centerYAnchor.constraint(equalTo: infoAuthorLabel.centerYAnchor),
            infoHashLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            infoHashLabel.widthAnchor.constraint(equalToConstant: 70),
            infoHashLabel.heightAnchor.constraint(equalToConstant: 16),
            infoAuthorLabel.trailingAnchor.constraint(lessThanOrEqualTo: infoHashLabel.leadingAnchor, constant: -8),

            infoDateLabel.topAnchor.constraint(equalTo: infoAuthorLabel.bottomAnchor, constant: 2),
            infoDateLabel.leadingAnchor.constraint(equalTo: infoAvatarView.trailingAnchor, constant: 8),
            infoDateLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),

            msgScroll.topAnchor.constraint(equalTo: infoAvatarView.bottomAnchor, constant: 8),
            msgScroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            msgScroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            msgScroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
        ])

        return panel
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        let visibleHeight = scrollView.documentVisibleRect.height
        let contentHeight = scrollView.documentView?.frame.height ?? 0
        let scrollY = scrollView.documentVisibleRect.origin.y
        
        // Trigger loadMore when scrolled within 100px of the bottom
        if scrollY + visibleHeight >= contentHeight - 100 {
            presenter?.loadMore()
        }
    }
    
    // MARK: - NSSplitViewDelegate
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 400 // Left pane min width
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.bounds.width - 260 // Right pane min width
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        splitPersistence?.saveDividerPositions()
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return commits.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < commits.count else { return nil }
        let commit = commits[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("CommitRowCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? CommitRowView
        
        if cellView == nil {
            cellView = CommitRowView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 28))
            cellView?.identifier = cellIdentifier
        }
        
        cellView?.configure(with: commit, maxLaneCount: maxLaneCount)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < commits.count else { return }
        presenter?.didSelectCommit(commits[selectedRow])
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < commits.count else { return }
        
        // Highlight right-clicked row for visual consistency
        if clickedRow != tableView.selectedRow {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        
        let commit = commits[clickedRow]
        presenter?.showContextMenu(for: commit, menu: menu)
    }
    
    // MARK: - HistoryViewProtocol
    
    func showHistory(_ commits: [CommitNode]) {
        self.commits = commits
        self.maxLaneCount = (commits.map { $0.laneIndex }.max() ?? 0) + 1
        
        // Precompute all parent hashes to determine incoming vertical lines quickly
        var parents = Set<String>()
        for commit in commits {
            for parent in commit.parents {
                parents.insert(parent)
            }
        }
        self.parentHashes = parents
        
        let selectedRow = tableView.selectedRow
        tableView.reloadData()
        
        // Preserve selection or select first row by default
        if selectedRow >= 0 && selectedRow < commits.count {
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        } else if !commits.isEmpty && tableView.selectedRow == -1 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    func updateCommitDetails(_ commit: CommitNode) {
        // Update left-pane info panel
        infoAvatarView.name = commit.author
        infoAuthorLabel.stringValue = commit.author
        infoHashLabel.stringValue = " \(commit.shortHash.uppercased()) "

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        infoDateLabel.stringValue = fmt.string(from: commit.date)
        infoMessageView.string = commit.message

        // Update right-pane files+diff
        detailVC.configure(with: commit)
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
