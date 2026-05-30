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
    
    // Split view persistence
    private var splitPersistence: SplitViewPersistence?
    
    // Child View Controller
    private let detailVC = CommitDetailViewController(nibName: "CommitDetailViewController", bundle: nil)
    
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
        
        // 2. Left Pane UI: NSScrollView + NSTableView
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor)
        ])
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.gridColor = NSColor.separatorColor
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.rowHeight = 28 // GraphMetrics.rowHeight
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
        
        let hasIncomingLine = parentHashes.contains(commit.hash)
        cellView?.configure(with: commit, maxLaneCount: maxLaneCount, hasIncomingLine: hasIncomingLine)
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
