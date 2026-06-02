// MARK: - ChangesViewController.swift

import Cocoa

protocol ChangesViewProtocol: AnyObject {
    func showStagedFiles(_ files: [GitFileStatus])
    func showUnstagedFiles(_ files: [GitFileStatus])
    func showDiffText(_ text: String, for file: String, isStaged: Bool)
    func showBinaryDiff(file: String, beforeSize: Int, afterSize: Int)
    func showConflictResolution(for filePath: String, repoPath: String)
    func clearDiff()
    func showLoading(_ loading: Bool)
    func showLastCommitMessage(_ message: String)
    func showConflictBanner(_ hasConflicts: Bool)
}

// MARK: - Pane minimum heights & UserDefaults keys

private enum FilesSplitMin {
    static let staged:   CGFloat = 80
    static let unstaged: CGFloat = 80
    static let commit:   CGFloat = 130
    static var total:    CGFloat { staged + unstaged + commit }
}

private enum FilesSplitKey {
    static let divider0 = "gitflow.changes.files.divider0"
    static let divider1 = "gitflow.changes.files.divider1"
}

class CommitTextView: NSTextView {
    var placeholderString: String = "Commit message..." {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: self.font ?? NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            
            let padding = self.textContainer?.lineFragmentPadding ?? 0
            let inset = self.textContainerInset
            let rect = NSRect(x: inset.width + padding, 
                              y: inset.height, 
                              width: bounds.width - inset.width * 2 - padding * 2, 
                              height: bounds.height)
            
            (placeholderString as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }
    
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}

class ChangesViewController: NSViewController, ChangesViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSplitViewDelegate, NSMenuDelegate {

    var presenter: ChangesPresenterProtocol?

    private var allStagedFiles: [GitFileStatus] = []
    private var allUnstagedFiles: [GitFileStatus] = []
    private var stagedFiles: [GitFileStatus] = []
    private var unstagedFiles: [GitFileStatus] = []
    private var searchQuery: String = ""

    // UI Split View Components
    @IBOutlet private weak var mainSplitView: NSSplitView!
    @IBOutlet private weak var leftSplitView: NSSplitView!

    // Main split persistence (left | right)
    private var mainSplitPersistence: SplitViewPersistence?

    // Table Views
    @IBOutlet private weak var stagedTableView: NSTableView!
    @IBOutlet private weak var unstagedTableView: NSTableView!

    // Diff View Components
    @IBOutlet private weak var diffTableView: NSTableView!
    @IBOutlet private weak var diffScrollView: NSScrollView!
    @IBOutlet private weak var diffTitleLabel: NSTextField!
    private var diffLines: [DiffLine] = []
    private var isShowingUnstagedDiff: Bool = true
    
    // Binary Diff View Components
    @IBOutlet private weak var diffBinaryView: NSView!
    @IBOutlet private weak var binaryBeforeSizeLabel: NSTextField!
    @IBOutlet private weak var binaryAfterSizeLabel: NSTextField!
    @IBOutlet private weak var binaryBeforeOpenButton: NSButton!
    @IBOutlet private weak var binaryAfterOpenButton: NSButton!
    private var currentBinaryFilePath: String?

    // Commit Box Components
    @IBOutlet private weak var commitTextView: CommitTextView!
    @IBOutlet private weak var commitButton: NSButton!
    @IBOutlet private weak var amendCheckbox: NSButton!
    @IBOutlet private weak var stageAllButton: NSButton!
    @IBOutlet private weak var stagedCheckbox: NSButton!
    @IBOutlet private weak var unstagedCheckbox: NSButton!
    @IBOutlet private weak var undoButton: NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var diffEmptyStateView: NSView!
    
    @IBOutlet private weak var conflictBannerContainer: NSView!
    @IBOutlet private weak var conflictBannerHeight: NSLayoutConstraint!
    private var conflictBanner: NSView!
    
    private var conflictVC: ConflictResolutionViewController?

    private var hasRestoredMainSplit = false
    private var hasRestoredLeftSplit = false
    private var hasQueuedMainSplitRestore = false
    private var hasQueuedLeftSplitRestore = false
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: "ChangesViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
        
        // Listen for file-system changes to auto-refresh data (no view rebuild)
        NotificationCenter.default.addObserver(self, selector: #selector(handleContentRefresh), name: .repositoryContentShouldRefresh, object: nil)
        
        // Listen for search query changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleSearchQueryChanged(_:)), name: .fileSearchQueryChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleContentRefresh() {
        presenter?.refresh()
    }
    
    @objc private func handleSearchQueryChanged(_ notification: Notification) {
        if let query = notification.userInfo?["query"] as? String {
            self.searchQuery = query.lowercased()
            applyFilter()
        }
    }
    
    private func applyFilter() {
        if searchQuery.isEmpty {
            stagedFiles = allStagedFiles
            unstagedFiles = allUnstagedFiles
        } else {
            stagedFiles = allStagedFiles.filter { $0.path.lowercased().contains(searchQuery) }
            unstagedFiles = allUnstagedFiles.filter { $0.path.lowercased().contains(searchQuery) }
        }
        stagedTableView.reloadData()
        unstagedTableView.reloadData()
        
        if stagedCheckbox != nil {
            stagedCheckbox.title = stagedFiles.isEmpty ? "Staged Changes" : "Staged Changes (\(stagedFiles.count))"
        }
        if unstagedCheckbox != nil {
            unstagedCheckbox.title = unstagedFiles.isEmpty ? "Unstaged Changes" : "Unstaged Changes (\(unstagedFiles.count))"
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Restore dividers after initial layout is complete and window is visible
        if !hasQueuedMainSplitRestore {
            hasQueuedMainSplitRestore = true
            DispatchQueue.main.async { [weak self] in
                self?.mainSplitPersistence?.restoreDividerPositions()
                self?.hasRestoredMainSplit = true
            }
        }
        
        if !hasQueuedLeftSplitRestore {
            hasQueuedLeftSplitRestore = true
            DispatchQueue.main.async { [weak self] in
                self?.restoreFilesDividerPositions()
                self?.hasRestoredLeftSplit = true
            }
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Re-clamp if the window shrank below saved positions
        if hasRestoredLeftSplit {
            let panes = leftSplitView.subviews
            guard panes.count == 3 else { return }
            
            let stagedH   = panes[0].frame.height
            let unstagedH = panes[1].frame.height
            let commitH   = panes[2].frame.height
            
            if stagedH   < FilesSplitMin.staged   ||
               unstagedH < FilesSplitMin.unstaged ||
               commitH   < FilesSplitMin.commit {
                restoreFilesDividerPositions()
            }
        }
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        mainSplitView.delegate = self
        // Wire main split persistence
        mainSplitPersistence = SplitViewPersistence(splitView: mainSplitView, key: "gitflow.split.changes")
        
        conflictBanner = buildConflictBanner()
        conflictBanner.translatesAutoresizingMaskIntoConstraints = false
        conflictBannerContainer.addSubview(conflictBanner)
        conflictBanner.pinToEdges(of: conflictBannerContainer)
        
        leftSplitView.delegate = self
        
        stagedTableView.dataSource = self
        stagedTableView.delegate = self
        
        unstagedTableView.dataSource = self
        unstagedTableView.delegate = self
        
        commitTextView.delegate = self
        
        if #available(macOS 11.0, *) {
            commitButton.bezelColor = NSColor.systemBlue
            commitButton.contentTintColor = .white
            
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            let attrTitle = NSAttributedString(string: "Commit", attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13),
                .paragraphStyle: pStyle
            ])
            commitButton.attributedTitle = attrTitle
        }
        
        diffTableView.dataSource = self
        diffTableView.delegate = self
        
        // Set double click actions on tables
        stagedTableView.doubleAction = #selector(stagedTableDoubleClicked(_:))
        unstagedTableView.doubleAction = #selector(unstagedTableDoubleClicked(_:))
        
        // Context menus (right-click)
        let stagedMenu = NSMenu()
        stagedMenu.delegate = self
        stagedMenu.identifier = NSUserInterfaceItemIdentifier("stagedMenu")
        stagedTableView.menu = stagedMenu
        
        let unstagedMenu = NSMenu()
        unstagedMenu.delegate = self
        unstagedMenu.identifier = NSUserInterfaceItemIdentifier("unstagedMenu")
        unstagedTableView.menu = unstagedMenu
    }
    
    // MARK: - Left split (3-pane) save/restore
    
    private func saveFilesDividerPositions() {
        guard hasRestoredLeftSplit else { return } // Do not save garbage during initial layout
        let total = leftSplitView.bounds.height
        guard total > FilesSplitMin.total else { return }
        
        let panes = leftSplitView.subviews
        guard panes.count == 3 else { return }
        
        let pos0 = Double(panes[0].frame.maxY)
        let pos1 = Double(panes[1].frame.maxY)
        
        let ud = UserDefaults.standard
        ud.set(pos0, forKey: FilesSplitKey.divider0)
        ud.set(pos1, forKey: FilesSplitKey.divider1)
    }
    
    private var isRestoringLeftSplit = false
    
    private func restoreFilesDividerPositions() {
        let ud    = UserDefaults.standard
        let total = leftSplitView.bounds.height
        let divT  = leftSplitView.dividerThickness
        
        guard total > FilesSplitMin.total else { return }
        
        // Force all panes to be visible (in case macOS built-in autosave corrupted them and hid them)
        leftSplitView.subviews.forEach { $0.isHidden = false }
        
        var pos0 = CGFloat(ud.double(forKey: FilesSplitKey.divider0))
        var pos1 = CGFloat(ud.double(forKey: FilesSplitKey.divider1))
        
        // First launch: no saved value → use default 40% / 80% ratios
        // This makes Commit message = 20%, and Staged/Unstaged share the remaining 80% equally (40% each)
        if pos0 == 0 || pos1 == 0 {
            pos0 = (total * 0.40).rounded()
            pos1 = (total * 0.80).rounded()
        }
        
        // Clamp: enforce min heights even if window was resized smaller
        pos0 = max(pos0, FilesSplitMin.staged)
        pos0 = min(pos0, total - FilesSplitMin.unstaged - FilesSplitMin.commit - divT * 2)
        
        pos1 = max(pos1, pos0 + divT + FilesSplitMin.unstaged)
        pos1 = min(pos1, total - FilesSplitMin.commit - divT)
        
        let panes = leftSplitView.subviews
        guard panes.count == 3 else { return }
        
        isRestoringLeftSplit = true
        panes[0].frame = NSRect(x: 0, y: 0, width: panes[0].bounds.width, height: pos0)
        panes[1].frame = NSRect(x: 0, y: pos0 + divT, width: panes[1].bounds.width, height: pos1 - pos0 - divT)
        panes[2].frame = NSRect(x: 0, y: pos1 + divT, width: panes[2].bounds.width, height: total - pos1 - divT)
        
        leftSplitView.adjustSubviews()
        isRestoringLeftSplit = false
    }
    
    // MARK: - Section builders
    
    private func createListSection(title: String) -> (view: NSView, tableView: NSTableView, checkbox: NSButton) {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = true
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let headerBar = NSView()
        headerBar.wantsLayer = true
        headerBar.layer?.backgroundColor = NSColor.clear.cgColor
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerBar)
        
        let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        checkbox.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(checkbox)
        
        let headerBorder = NSView()
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerBorder)
        
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        
        let table = NSTableView()
        table.headerView = nil
        table.backgroundColor = NSColor.clear
        table.gridStyleMask = []
        table.allowsMultipleSelection = false
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.rowHeight = 28
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fileColumn"))
        column.width = 300
        table.addTableColumn(column)
        
        table.dataSource = self
        table.delegate = self
        
        scroll.documentView = table
        
        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: container.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 32),
            
            checkbox.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            checkbox.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
            
            headerBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),
            
            scroll.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return (container, table, checkbox)
    }
    
    private func createCommitSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = true
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        scroll.layer?.borderColor = NSColor.gitFlowBorder.cgColor
        scroll.layer?.borderWidth = 1
        scroll.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        
        commitTextView = CommitTextView()
        commitTextView.isRichText = false
        commitTextView.isEditable = true
        commitTextView.font = NSFont.systemFont(ofSize: 13)
        commitTextView.textColor = NSColor.labelColor
        commitTextView.delegate = self
        commitTextView.insertionPointColor = NSColor.labelColor
        commitTextView.string = ""
        commitTextView.textContainerInset = NSSize(width: 8, height: 8)
        commitTextView.backgroundColor = .clear
        scroll.documentView = commitTextView
        
        amendCheckbox = NSButton(checkboxWithTitle: "Amend last commit", target: self, action: #selector(amendCheckboxChanged(_:)))
        amendCheckbox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(amendCheckbox)

        stageAllButton = NSButton(title: "Stage All", target: self, action: #selector(stageAllClicked(_:)))
        stageAllButton.bezelStyle = .push
        stageAllButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stageAllButton)

        commitButton = NSButton(title: "Commit", target: self, action: #selector(commitClicked(_:)))
        commitButton.bezelStyle = .push
        if #available(macOS 11.0, *) {
            commitButton.bezelColor = NSColor.systemBlue
            commitButton.contentTintColor = .white
            
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            let attrTitle = NSAttributedString(string: "Commit", attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13),
                .paragraphStyle: pStyle
            ])
            commitButton.attributedTitle = attrTitle
        }
        commitButton.keyEquivalent = "\r"
        commitButton.keyEquivalentModifierMask = .command
        commitButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(commitButton)

        undoButton = NSButton(title: "Undo", target: self, action: #selector(undoClicked(_:)))
        undoButton.bezelStyle = .push
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(undoButton)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: amendCheckbox.topAnchor, constant: -8),

            amendCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            amendCheckbox.bottomAnchor.constraint(equalTo: stageAllButton.topAnchor, constant: -6),

            stageAllButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stageAllButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            commitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            commitButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            commitButton.widthAnchor.constraint(equalToConstant: 85),
            
            undoButton.trailingAnchor.constraint(equalTo: commitButton.leadingAnchor, constant: -8),
            undoButton.centerYAnchor.constraint(equalTo: commitButton.centerYAnchor),
            undoButton.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }
    
    private func setupDiffContainer(in container: NSView) {
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        diffTitleLabel = NSTextField(labelWithString: "No file selected")
        diffTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        diffTitleLabel.textColor = NSColor.labelColor
        diffTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(diffTitleLabel)

        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(border)

        diffScrollView = NSScrollView()
        diffScrollView.hasVerticalScroller = true
        diffScrollView.hasHorizontalScroller = true
        diffScrollView.autohidesScrollers = true
        diffScrollView.borderType = .noBorder
        diffScrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(diffScrollView)

        diffTableView = NSTableView()
        diffTableView.headerView = nil
        diffTableView.backgroundColor = NSColor.controlBackgroundColor
        diffTableView.rowHeight = 18
        diffTableView.gridStyleMask = []
        diffTableView.intercellSpacing = NSSize(width: 0, height: 0)
        diffTableView.allowsMultipleSelection = true
        diffTableView.selectionHighlightStyle = .regular
        diffTableView.usesAlternatingRowBackgroundColors = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("diffCol"))
        col.resizingMask = []
        diffTableView.addTableColumn(col)
        diffTableView.columnAutoresizingStyle = .noColumnAutoresizing
        diffTableView.dataSource = self
        diffTableView.delegate = self

        diffScrollView.documentView = diffTableView

        NSLayoutConstraint.activate([
            diffTitleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            diffTitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            diffTitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            border.topAnchor.constraint(equalTo: diffTitleLabel.bottomAnchor, constant: 12),
            border.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),

            diffScrollView.topAnchor.constraint(equalTo: border.bottomAnchor),
            diffScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            diffScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            diffScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        diffEmptyStateView = NSView()
        diffEmptyStateView.translatesAutoresizingMaskIntoConstraints = false
        diffEmptyStateView.wantsLayer = true
        diffEmptyStateView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.addSubview(diffEmptyStateView)
        
        let emptyLabel = NSTextField(labelWithString: "No file selected")
        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = NSColor.secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        diffEmptyStateView.addSubview(emptyLabel)
        
        let iconView = NSImageView()
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            iconView.image = NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "Empty Diff")?.withSymbolConfiguration(config)
            iconView.contentTintColor = NSColor.tertiaryLabelColor
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        diffEmptyStateView.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            diffEmptyStateView.topAnchor.constraint(equalTo: border.bottomAnchor),
            diffEmptyStateView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            diffEmptyStateView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            diffEmptyStateView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: diffEmptyStateView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: diffEmptyStateView.centerYAnchor, constant: -20),
            
            emptyLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16)
        ])
        
        diffEmptyStateView.isHidden = false
        diffScrollView.isHidden = true
        
        setupBinaryDiffContainer(in: container, below: border)
    }
    
    private func setupBinaryDiffContainer(in container: NSView, below border: NSView) {
        diffBinaryView = NSView()
        diffBinaryView.translatesAutoresizingMaskIntoConstraints = false
        diffBinaryView.wantsLayer = true
        diffBinaryView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.addSubview(diffBinaryView)
        
        NSLayoutConstraint.activate([
            diffBinaryView.topAnchor.constraint(equalTo: border.bottomAnchor),
            diffBinaryView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            diffBinaryView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            diffBinaryView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Header Label & Control
        let headerContainer = NSView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.wantsLayer = true
        headerContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        diffBinaryView.addSubview(headerContainer)
        
        let headerLabel = NSTextField(labelWithString: "Modified binary file, diff suppressed (file size or pattern)")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        headerLabel.textColor = NSColor.tertiaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(headerLabel)
        
        let sideBySideButton = NSPopUpButton(frame: .zero, pullsDown: false)
        sideBySideButton.translatesAutoresizingMaskIntoConstraints = false
        sideBySideButton.addItem(withTitle: "Side-by-side")
        sideBySideButton.font = NSFont.systemFont(ofSize: 12)
        sideBySideButton.bezelStyle = .rounded
        sideBySideButton.isEnabled = false
        headerContainer.addSubview(sideBySideButton)
        
        // Left (Before)
        let leftContainer = NSView()
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        diffBinaryView.addSubview(leftContainer)
        
        let beforeLabel = NSTextField(labelWithString: "Before")
        beforeLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        beforeLabel.textColor = NSColor.systemRed
        beforeLabel.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(beforeLabel)
        
        let beforeNoPreview = NSTextField(labelWithString: "No Preview Available")
        beforeNoPreview.font = NSFont.systemFont(ofSize: 13)
        beforeNoPreview.textColor = NSColor.labelColor
        beforeNoPreview.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(beforeNoPreview)
        
        binaryBeforeSizeLabel = NSTextField(labelWithString: "0 bytes")
        binaryBeforeSizeLabel.font = NSFont.systemFont(ofSize: 13)
        binaryBeforeSizeLabel.textColor = NSColor.secondaryLabelColor
        binaryBeforeSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(binaryBeforeSizeLabel)
        
        binaryBeforeOpenButton = NSButton(title: "Open", target: self, action: #selector(openBinaryBeforeFile))
        binaryBeforeOpenButton.bezelStyle = .rounded
        binaryBeforeOpenButton.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(binaryBeforeOpenButton)
        
        // Right (After)
        let rightContainer = NSView()
        rightContainer.translatesAutoresizingMaskIntoConstraints = false
        diffBinaryView.addSubview(rightContainer)
        
        let afterLabel = NSTextField(labelWithString: "After")
        afterLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        afterLabel.textColor = NSColor.systemGreen
        afterLabel.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(afterLabel)
        
        let afterNoPreview = NSTextField(labelWithString: "No Preview Available")
        afterNoPreview.font = NSFont.systemFont(ofSize: 13)
        afterNoPreview.textColor = NSColor.labelColor
        afterNoPreview.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(afterNoPreview)
        
        binaryAfterSizeLabel = NSTextField(labelWithString: "0 bytes")
        binaryAfterSizeLabel.font = NSFont.systemFont(ofSize: 13)
        binaryAfterSizeLabel.textColor = NSColor.secondaryLabelColor
        binaryAfterSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(binaryAfterSizeLabel)
        
        binaryAfterOpenButton = NSButton(title: "Open", target: self, action: #selector(openBinaryAfterFile))
        binaryAfterOpenButton.bezelStyle = .rounded
        binaryAfterOpenButton.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(binaryAfterOpenButton)
        
        let centerDivider = NSView()
        centerDivider.wantsLayer = true
        centerDivider.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        centerDivider.translatesAutoresizingMaskIntoConstraints = false
        diffBinaryView.addSubview(centerDivider)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: diffBinaryView.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: diffBinaryView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: diffBinaryView.trailingAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 32),
            
            headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
            headerLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            sideBySideButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
            sideBySideButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            leftContainer.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            leftContainer.leadingAnchor.constraint(equalTo: diffBinaryView.leadingAnchor),
            leftContainer.bottomAnchor.constraint(equalTo: diffBinaryView.bottomAnchor),
            leftContainer.trailingAnchor.constraint(equalTo: centerDivider.leadingAnchor),
            
            rightContainer.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            rightContainer.trailingAnchor.constraint(equalTo: diffBinaryView.trailingAnchor),
            rightContainer.bottomAnchor.constraint(equalTo: diffBinaryView.bottomAnchor),
            rightContainer.leadingAnchor.constraint(equalTo: centerDivider.trailingAnchor),
            
            centerDivider.centerXAnchor.constraint(equalTo: diffBinaryView.centerXAnchor),
            centerDivider.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 32),
            centerDivider.bottomAnchor.constraint(equalTo: diffBinaryView.bottomAnchor, constant: -32),
            centerDivider.widthAnchor.constraint(equalToConstant: 1),
            
            // Left Content
            beforeLabel.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            beforeLabel.topAnchor.constraint(equalTo: leftContainer.topAnchor, constant: 32),
            
            beforeNoPreview.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            beforeNoPreview.topAnchor.constraint(equalTo: beforeLabel.bottomAnchor, constant: 64),
            
            binaryBeforeSizeLabel.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            binaryBeforeSizeLabel.topAnchor.constraint(equalTo: beforeNoPreview.bottomAnchor, constant: 8),
            
            binaryBeforeOpenButton.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            binaryBeforeOpenButton.topAnchor.constraint(equalTo: binaryBeforeSizeLabel.bottomAnchor, constant: 16),
            
            // Right Content
            afterLabel.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            afterLabel.topAnchor.constraint(equalTo: rightContainer.topAnchor, constant: 32),
            
            afterNoPreview.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            afterNoPreview.topAnchor.constraint(equalTo: afterLabel.bottomAnchor, constant: 64),
            
            binaryAfterSizeLabel.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            binaryAfterSizeLabel.topAnchor.constraint(equalTo: afterNoPreview.bottomAnchor, constant: 8),
            
            binaryAfterOpenButton.centerXAnchor.constraint(equalTo: rightContainer.centerXAnchor),
            binaryAfterOpenButton.topAnchor.constraint(equalTo: binaryAfterSizeLabel.bottomAnchor, constant: 16)
        ])
        
        diffBinaryView.isHidden = true
    }
    
    // MARK: - Actions
    
    @objc private func undoClicked(_ sender: NSButton) {
        presenter?.didClickUndoLastCommit()
    }
    
    @objc private func openBinaryBeforeFile() {
        // "Before" doesn't have a working tree file natively in exactly the same path, 
        // usually it requires extracting from git index.
        // For now, we can just attempt to show it via GitService or alert user it's read-only
        let alert = NSAlert()
        alert.messageText = "Not Available"
        alert.informativeText = "Viewing the previous version directly from the index is not fully supported yet."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func openBinaryAfterFile() {
        guard let path = currentBinaryFilePath,
              let activePath = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        let fullPath = (activePath as NSString).appendingPathComponent(path)
        NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
    }
    
    @objc private func stagedTableDoubleClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0 && row < stagedFiles.count else { return }
        presenter?.didDoubleClickFile(stagedFiles[row])
    }
    
    @objc private func unstagedTableDoubleClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0 && row < unstagedFiles.count else { return }
        presenter?.didDoubleClickFile(unstagedFiles[row])
    }
    
    @objc private func unstagedCheckboxToggled(_ sender: NSButton) {
        // Automatically becomes .on when clicked natively.
        // Wait 0.1s for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Revert back to .off because this is the Unstaged header
            sender.state = .off
            guard let self = self, !self.unstagedFiles.isEmpty else { return }
            self.presenter?.didClickStageAll()
        }
    }
    
    @objc private func stagedCheckboxToggled(_ sender: NSButton) {
        // Automatically becomes .off when clicked natively.
        // Wait 0.1s for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Revert back to .on because this is the Staged header
            sender.state = .on
            guard let self = self, !self.stagedFiles.isEmpty else { return }
            self.presenter?.didClickUnstageAll()
        }
    }

    @objc private func stageAllClicked(_ sender: Any) {
        presenter?.didClickStageAll()
    }
    
    @objc private func unstageAllClicked(_ sender: NSButton) {
        presenter?.didClickUnstageAll()
    }
    
    @objc private func commitClicked(_ sender: NSButton) {
        let message = commitTextView.string
        let amend = amendCheckbox.state == .on
        presenter?.didClickCommit(message: message, amend: amend)
        commitTextView.string = ""
        amendCheckbox.state = .off
    }

    @objc private func amendCheckboxChanged(_ sender: NSButton) {
        if sender.state == .on {
            presenter?.didRequestLastCommitMessage()
        }
    }
    
    @objc private func fileCheckboxToggled(_ sender: NSButton) {
        guard let cell = sender.superview as? NSTableCellView else { return }
        
        let rowStaged = stagedTableView.row(for: cell)
        if rowStaged != -1, rowStaged < stagedFiles.count {
            let file = stagedFiles[rowStaged]
            presenter?.didDoubleClickFile(file)
            sender.state = .on // Revert visually until model updates
            return
        }
        
        let rowUnstaged = unstagedTableView.row(for: cell)
        if rowUnstaged != -1, rowUnstaged < unstagedFiles.count {
            let file = unstagedFiles[rowUnstaged]
            presenter?.didDoubleClickFile(file)
            sender.state = .off // Revert visually until model updates
            return
        }
    }
    // MARK: - Context Menu (NSMenuDelegate)
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let isStaged = menu.identifier?.rawValue == "stagedMenu"
        let table = isStaged ? stagedTableView! : unstagedTableView!
        let row = table.clickedRow
        guard row >= 0 else { return }
        
        let files = isStaged ? stagedFiles : unstagedFiles
        guard row < files.count else { return }
        let file = files[row]
        
        // Select the clicked row
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        
        if isStaged {
            let unstageItem = NSMenuItem(title: "Unstage File", action: #selector(contextUnstageFile(_:)), keyEquivalent: "")
            unstageItem.representedObject = file
            menu.addItem(unstageItem)
        } else {
            let stageTitle = file.status == "U" ? "Mark as Resolved (git add)" : "Stage File"
            let stageItem = NSMenuItem(title: stageTitle, action: #selector(contextStageFile(_:)), keyEquivalent: "")
            stageItem.representedObject = file
            menu.addItem(stageItem)
            
            let discardItem = NSMenuItem(title: "Discard Changes", action: #selector(contextDiscardFile(_:)), keyEquivalent: "")
            discardItem.representedObject = file
            menu.addItem(discardItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        if !isStaged {
            let removeItem = NSMenuItem(title: "Remove File", action: #selector(contextRemoveFile(_:)), keyEquivalent: "")
            removeItem.representedObject = file
            menu.addItem(removeItem)
            
            let ignoreItem = NSMenuItem(title: "Ignore File", action: #selector(contextIgnoreFile(_:)), keyEquivalent: "")
            ignoreItem.representedObject = file
            menu.addItem(ignoreItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder(_:)), keyEquivalent: "")
        finderItem.representedObject = file
        menu.addItem(finderItem)
    }
    
    @objc private func contextStageFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        presenter?.didDoubleClickFile(file) // stage action
    }
    
    @objc private func contextUnstageFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        presenter?.didDoubleClickFile(file) // unstage action
    }
    
    @objc private func contextDiscardFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        let alert = NSAlert()
        alert.messageText = "Discard Changes?"
        alert.informativeText = "Are you sure you want to discard changes to \"\(file.path)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            presenter?.didClickDiscard(file)
        }
    }
    
    @objc private func contextRemoveFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        let alert = NSAlert()
        alert.messageText = "Remove File?"
        alert.informativeText = "Are you sure you want to remove \"\(file.path)\" from the repository?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            presenter?.didClickRemoveFile(file)
        }
    }
    
    @objc private func contextIgnoreFile(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        presenter?.didClickIgnoreFile(file)
    }
    
    @objc private func contextShowInFinder(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? GitFileStatus else { return }
        presenter?.didClickShowInFinder(file)
    }
    
    @objc func copy(_ sender: Any?) {
        guard let window = view.window, window.firstResponder == diffTableView else {
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
    
    // MARK: - NSSplitViewDelegate
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === mainSplitView {
            return 220 // Left pane min width
        }
        
        if splitView === leftSplitView {
            let panes = splitView.subviews
            guard panes.count == 3 else { return proposedMinimumPosition }
            
            if isRestoringLeftSplit {
                switch dividerIndex {
                case 0: return FilesSplitMin.staged
                case 1: return FilesSplitMin.staged + splitView.dividerThickness + FilesSplitMin.unstaged
                default: break
                }
                return proposedMinimumPosition
            }
            
            switch dividerIndex {
            case 0:
                // Divider 0 cannot go above minHeight of staged pane
                return FilesSplitMin.staged
            case 1:
                // Divider 1 must stay below divider 0 + unstaged min height
                let div0_maxY = panes[0].frame.maxY
                return div0_maxY + splitView.dividerThickness + FilesSplitMin.unstaged
            default:
                break
            }
        }
        return proposedMinimumPosition
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === mainSplitView {
            return splitView.bounds.width - 400 // Right pane (diff) min width
        }
        if splitView === leftSplitView {
            let panes = splitView.subviews
            guard panes.count == 3 else { return proposedMaximumPosition }
            
            let total = splitView.bounds.height
            let divT  = splitView.dividerThickness
            
            if isRestoringLeftSplit {
                switch dividerIndex {
                case 0: return total - FilesSplitMin.unstaged - FilesSplitMin.commit - divT * 2
                case 1: return total - FilesSplitMin.commit - divT
                default: break
                }
                return proposedMaximumPosition
            }
            
            switch dividerIndex {
            case 0:
                // Divider 0 must stay above divider 1 - unstaged min height
                let div1_minY = panes[1].frame.maxY
                return div1_minY - divT - FilesSplitMin.unstaged
            case 1:
                // Divider 1 cannot go below total - commit min height
                return total - FilesSplitMin.commit - divT
            default:
                break
            }
        }
        return proposedMaximumPosition
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard let sv = notification.object as? NSSplitView else { return }
        if sv === mainSplitView {
            mainSplitPersistence?.saveDividerPositions()
        } else if sv === leftSplitView {
            saveFilesDividerPositions()
        }
    }
    
    // MARK: - NSTableViewDataSource & Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === stagedTableView   { return stagedFiles.count }
        if tableView === unstagedTableView { return unstagedFiles.count }
        if tableView === diffTableView     { return diffLines.count }
        return 0
    }

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
        if tableView === diffTableView {
            return diffCellView(for: row)
        }

        let file = tableView === stagedTableView ? stagedFiles[row] : unstagedFiles[row]

        let identifier = NSUserInterfaceItemIdentifier("fileCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(fileCheckboxToggled(_:)))
            checkbox.identifier = NSUserInterfaceItemIdentifier("fileCheckbox")
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(checkbox)

            // Badge container — provides padding around the text
            let badgeContainer = NSView()
            badgeContainer.identifier = NSUserInterfaceItemIdentifier("badgeContainer")
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.cornerRadius = 4
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(badgeContainer)

            let statusBadge = NSTextField(labelWithString: "")
            statusBadge.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            statusBadge.alignment = .center
            statusBadge.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.addSubview(statusBadge)

            NSLayoutConstraint.activate([
                statusBadge.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
                statusBadge.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),
                statusBadge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            ])

            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            checkbox.setContentHuggingPriority(.required, for: .horizontal)

            NSLayoutConstraint.activate([
                checkbox.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                checkbox.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),

                badgeContainer.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
                badgeContainer.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                badgeContainer.widthAnchor.constraint(equalToConstant: 24),
                badgeContainer.heightAnchor.constraint(equalToConstant: 18),

                label.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        if let checkbox = cell?.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.identifier?.rawValue == "fileCheckbox" }) {
            checkbox.state = (tableView === stagedTableView) ? .on : .off
        }

        if let textField = cell?.textField {
            let path = file.path
            let nsPath = path as NSString
            let extensionStr = nsPath.pathExtension
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingMiddle
            
            let attrString = NSMutableAttributedString(string: path, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ])
            
            if !extensionStr.isEmpty {
                let targetExt = "." + extensionStr
                let range = nsPath.range(of: targetExt, options: .backwards)
                if range.location != NSNotFound {
                    attrString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .bold), range: range)
                }
            }
            textField.attributedStringValue = attrString
        }

        // Locate the badge container
        if let container = cell?.subviews.first(where: { $0.identifier?.rawValue == "badgeContainer" }),
           let badge = container.subviews.first as? NSTextField {
            badge.stringValue = file.status == "U" ? "!" : file.status
            switch file.status {
            case "A", "?":
                badge.textColor = NSColor.gitFlowStagedAddText
                container.layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor
            case "D":
                badge.textColor = NSColor.gitFlowStagedDeleteText
                container.layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor
            case "M":
                badge.textColor = NSColor.gitFlowModifiedText
                container.layer?.backgroundColor = NSColor.gitFlowModified.cgColor
            case "U":
                badge.textColor = NSColor.gitFlowConflictText
                container.layer?.backgroundColor = NSColor.gitFlowConflict.cgColor
            default:
                badge.textColor = NSColor.gitFlowAccent
                container.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
            }
        }

        return cell
    }

    private func diffCellView(for row: Int) -> NSView? {
        guard row < diffLines.count else { return nil }
        let line = diffLines[row]

        if case .hunkHeader(let hunk) = line.kind {
            let id = NSUserInterfaceItemIdentifier("HunkHeaderCell")
            var cell = diffTableView.makeView(withIdentifier: id, owner: self) as? HunkHeaderCellView
            if cell == nil {
                cell = HunkHeaderCellView()
                cell?.identifier = id
            }
            cell?.configure(headerText: line.rawText, isUnstagedDiff: isShowingUnstagedDiff)
            cell?.onStageHunk = { [weak self] in
                self?.presenter?.didClickStageHunk(patch: hunk.patch)
            }
            cell?.onDiscardHunk = { [weak self] in
                guard let self = self else { return }
                let alert = NSAlert()
                alert.messageText = "Discard Hunk?"
                alert.informativeText = "Are you sure? This cannot be undone."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Discard")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                self.presenter?.didClickDiscardHunk(patch: hunk.patch)
            }
            cell?.onUnstageHunk = { [weak self] in
                self?.presenter?.didClickUnstageHunk(patch: hunk.patch)
            }
            return cell
        }

        let id = NSUserInterfaceItemIdentifier("DiffLineCell")
        var cell = diffTableView.makeView(withIdentifier: id, owner: self) as? DiffLineCellView
        if cell == nil {
            cell = DiffLineCellView()
            cell?.identifier = id
        }
        cell?.configure(with: line)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }

        if table === stagedTableView {
            unstagedTableView.deselectAll(nil)
            presenter?.didSelectFile(stagedFiles[row])
        } else if table === unstagedTableView {
            stagedTableView.deselectAll(nil)
            presenter?.didSelectFile(unstagedFiles[row])
        }
        // diffTableView selection: intentionally ignored
    }
    
    // MARK: - NSTextViewDelegate
    
    func textDidChange(_ notification: Notification) {
        // Redraw will be handled by CommitTextView subclass
    }
    
    // MARK: - ChangesViewProtocol
    
    func showStagedFiles(_ files: [GitFileStatus]) {
        let previousSelection = stagedTableView.selectedRow >= 0 && stagedTableView.selectedRow < stagedFiles.count
            ? stagedFiles[stagedTableView.selectedRow].path : nil
        allStagedFiles = files
        applyFilter()
        if let selected = previousSelection,
           let newIdx = stagedFiles.firstIndex(where: { $0.path == selected }) {
            stagedTableView.selectRowIndexes(IndexSet(integer: newIdx), byExtendingSelection: false)
        }
    }
    
    func showUnstagedFiles(_ files: [GitFileStatus]) {
        let previousSelection = unstagedTableView.selectedRow >= 0 && unstagedTableView.selectedRow < unstagedFiles.count
            ? unstagedFiles[unstagedTableView.selectedRow].path : nil
        allUnstagedFiles = files
        applyFilter()
        if let selected = previousSelection,
           let newIdx = unstagedFiles.firstIndex(where: { $0.path == selected }) {
            unstagedTableView.selectRowIndexes(IndexSet(integer: newIdx), byExtendingSelection: false)
        }
    }
    
    func showConflictResolution(for filePath: String, repoPath: String) {
        removeConflictUI()
        
        let vc = ConflictResolutionViewController(filePath: filePath, repoPath: repoPath)
        vc.delegate = self
        self.addChild(vc)
        
        guard let container = diffScrollView.superview else { return }
        container.addSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: diffScrollView.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: diffScrollView.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: diffScrollView.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: diffScrollView.bottomAnchor)
        ])
        
        self.conflictVC = vc
        diffScrollView.isHidden = true
    }
    
    private func removeConflictUI() {
        if let vc = conflictVC {
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            self.conflictVC = nil
        }
    }
    
    func showDiffText(_ text: String, for file: String, isStaged: Bool) {
        removeConflictUI()
        diffTitleLabel.stringValue = file
        self.isShowingUnstagedDiff = !isStaged
        
        diffEmptyStateView.isHidden = true
        diffScrollView.isHidden = false
        diffBinaryView.isHidden = true
        let hunks = parseDiffHunks(from: text)
        diffLines = buildDiffLines(from: text, hunks: hunks)
        
        let maxLineLength = diffLines.map { $0.rawText.count }.max() ?? 0
        let contentWidth = CGFloat(maxLineLength) * 8.0 + 80 // Approx 8px per char + gutter padding
        if let col = diffTableView.tableColumns.first {
            col.width = max(diffScrollView.bounds.width, contentWidth)
        }
        
        diffTableView.reloadData()
        if !diffLines.isEmpty {
            diffTableView.scrollRowToVisible(0)
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        let formattedString = formatter.string(fromByteCount: Int64(bytes))
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = "."
        let bytesString = numberFormatter.string(from: NSNumber(value: bytes)) ?? "\(bytes)"
        
        return "\(formattedString) (\(bytesString) bytes)"
    }
    
    func showBinaryDiff(file: String, beforeSize: Int, afterSize: Int) {
        removeConflictUI()
        diffTitleLabel.stringValue = file
        self.currentBinaryFilePath = file
        
        diffEmptyStateView.isHidden = true
        diffScrollView.isHidden = true
        diffBinaryView.isHidden = false
        
        binaryBeforeSizeLabel.stringValue = formatSize(beforeSize)
        binaryAfterSizeLabel.stringValue = formatSize(afterSize)
        
        // Ensure "After" open button works if size > 0
        binaryAfterOpenButton.isEnabled = afterSize > 0
        binaryBeforeOpenButton.isEnabled = beforeSize > 0
    }

    func showLastCommitMessage(_ message: String) {
        commitTextView.string = message
        amendCheckbox.state = .on
    }

    func showConflictBanner(_ hasConflicts: Bool) {
        guard conflictBannerHeight.constant != (hasConflicts ? 36 : 0) else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            conflictBannerHeight.animator().constant = hasConflicts ? 36 : 0
        }
    }

    private func buildConflictBanner() -> NSView {
        let banner = NSView()
        banner.wantsLayer = true
        banner.layer?.masksToBounds = true   // clip subviews when height = 0
        banner.layer?.backgroundColor = NSColor.gitFlowConflict.cgColor

        let icon = NSTextField(labelWithString: "⚠")
        icon.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        icon.textColor = NSColor.gitFlowConflictText
        icon.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(icon)

        let label = NSTextField(labelWithString: "Merge conflict — resolve conflicts and mark files as resolved, then commit")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.gitFlowConflictText
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -10),
        ])
        return banner
    }

    func clearDiff() {
        removeConflictUI()
        diffTitleLabel.stringValue = "No file selected"
        diffLines.removeAll()
        diffTableView.reloadData()
        
        diffEmptyStateView.isHidden = false
        diffScrollView.isHidden = true
        diffBinaryView.isHidden = true
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
    
}

// MARK: - ConflictResolutionDelegate
extension ChangesViewController: ConflictResolutionDelegate {
    func didResolveConflict(in filePath: String) {
        presenter?.refresh()
    }
}
