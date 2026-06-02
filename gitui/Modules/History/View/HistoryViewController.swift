// MARK: - HistoryViewController.swift

import Cocoa

protocol HistoryViewProtocol: AnyObject {
    func showHistory(_ commits: [CommitNode])
    func updateCommitDetails(_ commit: CommitNode)
    func showLoading(_ loading: Bool)
}

class HistoryViewController: NSViewController, HistoryViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSSplitViewDelegate, NSSearchFieldDelegate {
    
    var presenter: HistoryPresenterProtocol?
    
    private var commits: [CommitNode] = []
    private var maxLaneCount: Int = 1
    private var parentHashes: Set<String> = []
    
    // UI Elements
    @IBOutlet private weak var splitView: NSSplitView!
    @IBOutlet private weak var leftContainer: NSView!
    @IBOutlet private weak var rightContainer: NSView!
    @IBOutlet private weak var scrollView: NSScrollView!
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    // Search Bar
    @IBOutlet private weak var searchContainer: NSView!
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet private weak var filterPopup: NSPopUpButton!

    // Commit info panel (bottom of left pane)
    @IBOutlet private weak var infoPanel: NSView!
    @IBOutlet private weak var infoAvatarView: AvatarView!
    @IBOutlet private weak var infoAuthorLabel: NSTextField!
    @IBOutlet private weak var infoDateLabel: NSTextField!
    @IBOutlet private weak var infoHashLabel: NSTextField!
    @IBOutlet private weak var infoMessageView: NSTextView!

    // Split view persistence
    private var splitPersistence: SplitViewPersistence?

    // Child View Controller
    private let detailVC = CommitDetailViewController()
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: "HistoryViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

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
        
        splitView.delegate = self
        
        // Wire persistence (sets autosaveName + identifier internally)
        splitPersistence = SplitViewPersistence(splitView: splitView, key: "gitflow.split.history")
        
        // Set default divider position only if no saved position exists
        if UserDefaults.standard.array(forKey: "gitflow.split.history") == nil {
            splitView.setPosition(680, ofDividerAt: 0)
        }
        
        searchField.delegate = self
        
        infoHashLabel.wantsLayer = true
        infoHashLabel.layer?.cornerRadius = 3
        infoHashLabel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        infoMessageView.isRichText = false
        infoMessageView.isEditable = false
        infoMessageView.font = NSFont.systemFont(ofSize: 12)
        infoMessageView.textColor = .labelColor
        infoMessageView.backgroundColor = .clear
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // Setup table view context menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        
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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - NSSearchFieldDelegate
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSSearchField, field == searchField {
            let query = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let filterType: GitSearchFilterType = filterPopup.titleOfSelectedItem == "Author" ? .author : .message
            presenter?.performSearch(query: query, filterType: filterType)
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
        let extraRow = (presenter?.hasMoreCommits == true) ? 1 : 0
        return commits.count + extraRow
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if row == commits.count { return 40 } // Load more row height
        guard row < commits.count else { return 24 }
        let commit = commits[row]
        return commit.refs.isEmpty ? 24 : GraphMetrics.rowHeight
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Render the load more cell
        if row == commits.count {
            presenter?.loadMore() // Trigger load more!
            
            let cell = NSTableCellView()
            let textField = NSTextField(labelWithString: "Loading more history...")
            textField.font = .systemFont(ofSize: 12)
            textField.textColor = .secondaryLabelColor
            textField.alignment = .center
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }
        
        guard row < commits.count else { return nil }
        
        let commit = commits[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("CommitRowCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? CommitRowView
        
        if cellView == nil {
            cellView = CommitRowView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: GraphMetrics.rowHeight))
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
