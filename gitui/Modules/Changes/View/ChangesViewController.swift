// MARK: - ChangesViewController.swift

import Cocoa

protocol ChangesViewProtocol: AnyObject {
    func showStagedFiles(_ files: [GitFileStatus])
    func showUnstagedFiles(_ files: [GitFileStatus])
    func showDiffText(_ text: String, for file: String, isStaged: Bool)
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

class ChangesViewController: NSViewController, ChangesViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSplitViewDelegate, NSMenuDelegate {

    var presenter: ChangesPresenterProtocol?

    private var stagedFiles: [GitFileStatus] = []
    private var unstagedFiles: [GitFileStatus] = []

    // UI Split View Components
    private var mainSplitView: NSSplitView!
    private var leftSplitView: NSSplitView!

    // Main split persistence (left | right)
    private var mainSplitPersistence: SplitViewPersistence?

    // Table Views
    private var stagedTableView: NSTableView!
    private var unstagedTableView: NSTableView!

    // Diff View Components
    private var diffTableView: NSTableView!
    private var diffScrollView: NSScrollView!
    private var diffTitleLabel: NSTextField!
    private var diffLines: [DiffLine] = []
    private var isShowingUnstagedDiff: Bool = true

    // Commit Box Components
    private var commitTextView: NSTextView!
    private var commitButton: NSButton!
    private var amendCheckbox: NSButton!
    private var stageAllButton: NSButton!
    private var unstageAllButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    private var conflictBanner: NSView!
    private var conflictBannerHeight: NSLayoutConstraint!

    private var hasRestoredMainSplit = false
    private var hasRestoredLeftSplit = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
        
        // Listen for file-system changes to auto-refresh data (no view rebuild)
        NotificationCenter.default.addObserver(self, selector: #selector(handleContentRefresh), name: .repositoryContentShouldRefresh, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleContentRefresh() {
        presenter?.refresh()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Restore dividers after initial layout is complete and window is visible
        if !hasRestoredMainSplit {
            mainSplitPersistence?.restoreDividerPositions()
            hasRestoredMainSplit = true
        }
        
        if !hasRestoredLeftSplit {
            restoreFilesDividerPositions()
            hasRestoredLeftSplit = true
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
        
        // 1. Setup Main Split View (Horizontal: Left list, Right diff)
        mainSplitView = NSSplitView()
        mainSplitView.isVertical = true
        mainSplitView.dividerStyle = .thin
        mainSplitView.delegate = self
        mainSplitView.pinToEdges(of: view)
        
        // Wire main split persistence
        mainSplitPersistence = SplitViewPersistence(splitView: mainSplitView, key: "gitflow.split.changes")
        
        let leftContainer = NSView()
        leftContainer.autoresizingMask = [.width, .height]
        leftContainer.frame = NSRect(x: 0, y: 0, width: 200, height: 500) // Crucial for NSSplitView initial layout
        
        let rightContainer = NSView()
        rightContainer.autoresizingMask = [.width, .height]
        rightContainer.frame = NSRect(x: 0, y: 0, width: 400, height: 500) // Crucial for NSSplitView initial layout
        
        mainSplitView.addArrangedSubview(leftContainer)
        mainSplitView.addArrangedSubview(rightContainer)
        
        // 2a. Conflict banner (hidden initially)
        conflictBanner = buildConflictBanner()
        conflictBanner.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(conflictBanner)
        conflictBannerHeight = conflictBanner.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            conflictBanner.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            conflictBanner.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            conflictBanner.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            conflictBannerHeight,
        ])

        // 2b. Setup Left Split View (Vertical: Staged, Unstaged, Commit Box)
        leftSplitView = NSSplitView()
        leftSplitView.isVertical = false
        leftSplitView.dividerStyle = .thin
        leftSplitView.delegate = self
        leftSplitView.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(leftSplitView)
        NSLayoutConstraint.activate([
            leftSplitView.topAnchor.constraint(equalTo: conflictBanner.bottomAnchor),
            leftSplitView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            leftSplitView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            leftSplitView.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),
        ])
        
        let stagedResult = createListSection(title: "Staged Changes")
        let stagedBox = stagedResult.view
        stagedBox.frame = NSRect(x: 0, y: 0, width: 200, height: 100) // Crucial for NSSplitView initial layout
        stagedTableView = stagedResult.tableView
        
        let unstagedResult = createListSection(title: "Unstaged Changes")
        let unstagedBox = unstagedResult.view
        unstagedBox.frame = NSRect(x: 0, y: 0, width: 200, height: 100) // Crucial for NSSplitView initial layout
        unstagedTableView = unstagedResult.tableView
        
        let commitBox = createCommitSection()
        commitBox.frame = NSRect(x: 0, y: 0, width: 200, height: 100) // Crucial for NSSplitView initial layout
        
        leftSplitView.addArrangedSubview(stagedBox)
        leftSplitView.addArrangedSubview(unstagedBox)
        leftSplitView.addArrangedSubview(commitBox)
        
        // Set holding priorities so NSSplitView knows which panes to resize first when the window shrinks.
        // Lowest priority resizes first. We want staged/unstaged to shrink before the commit box.
        leftSplitView.setHoldingPriority(NSLayoutConstraint.Priority(250), forSubviewAt: 0)
        leftSplitView.setHoldingPriority(NSLayoutConstraint.Priority(251), forSubviewAt: 1)
        leftSplitView.setHoldingPriority(NSLayoutConstraint.Priority(252), forSubviewAt: 2)
        
        // 3. Setup Right Container (Diff Viewer)
        setupDiffContainer(in: rightContainer)
        
        // 4. Progress Loading
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
        
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
    
    private func createListSection(title: String) -> (view: NSView, tableView: NSTableView) {
        let container = NSView()
        // MUST NOT be false for NSSplitView manual subview frame layout!
        container.translatesAutoresizingMaskIntoConstraints = true
        container.autoresizingMask = [.width, .height]
        
        let headerBar = NSView()
        headerBar.wantsLayer = true
        headerBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6).cgColor
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerBar)
        
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor.secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(label)
        
        let headerBorder = NSView()
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
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
        table.backgroundColor = NSColor.controlBackgroundColor
        table.gridColor = NSColor.separatorColor
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.allowsMultipleSelection = false
        
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
            headerBar.heightAnchor.constraint(equalToConstant: 26),
            
            label.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
            
            headerBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),
            
            scroll.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return (container, table)
    }
    
    private func createCommitSection() -> NSView {
        let container = NSView()
        // MUST NOT be false for NSSplitView manual subview frame layout!
        container.translatesAutoresizingMaskIntoConstraints = true
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(border)
        
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        
        commitTextView = NSTextView()
        commitTextView.isRichText = false
        commitTextView.isEditable = true
        commitTextView.font = NSFont.systemFont(ofSize: 12)
        commitTextView.textColor = NSColor.labelColor
        commitTextView.delegate = self
        commitTextView.insertionPointColor = NSColor.labelColor
        commitTextView.string = ""
        scroll.documentView = commitTextView
        
        // Placeholder label overlay
        let placeholder = NSTextField(labelWithString: "Commit message...")
        placeholder.font = NSFont.systemFont(ofSize: 12)
        placeholder.textColor = NSColor.placeholderTextColor
        placeholder.identifier = NSUserInterfaceItemIdentifier("commitPlaceholder")
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isSelectable = false
        scroll.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 1),
            placeholder.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 5)
        ])
        
        amendCheckbox = NSButton(checkboxWithTitle: "Amend last commit", target: self, action: #selector(amendCheckboxChanged(_:)))
        amendCheckbox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(amendCheckbox)

        stageAllButton = NSButton(title: "Stage All", target: self, action: #selector(stageAllClicked(_:)))
        stageAllButton.bezelStyle = .push
        stageAllButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stageAllButton)

        unstageAllButton = NSButton(title: "Unstage All", target: self, action: #selector(unstageAllClicked(_:)))
        unstageAllButton.bezelStyle = .push
        unstageAllButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(unstageAllButton)

        commitButton = NSButton(title: "Commit", target: self, action: #selector(commitClicked(_:)))
        commitButton.bezelStyle = .push
        commitButton.keyEquivalent = "\r"
        commitButton.keyEquivalentModifierMask = .command
        commitButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(commitButton)

        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: container.topAnchor),
            border.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),

            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: amendCheckbox.topAnchor, constant: -8),

            amendCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            amendCheckbox.bottomAnchor.constraint(equalTo: stageAllButton.topAnchor, constant: -6),

            stageAllButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stageAllButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            unstageAllButton.leadingAnchor.constraint(equalTo: stageAllButton.trailingAnchor, constant: 8),
            unstageAllButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            commitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            commitButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            commitButton.widthAnchor.constraint(equalToConstant: 85)
        ])
        
        return container
    }
    
    private func setupDiffContainer(in container: NSView) {
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        diffTitleLabel = NSTextField(labelWithString: "No file selected")
        diffTitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
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
        diffTableView.selectionHighlightStyle = .none
        diffTableView.usesAlternatingRowBackgroundColors = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("diffCol"))
        col.resizingMask = .autoresizingMask
        diffTableView.addTableColumn(col)
        diffTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
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
    }
    
    // MARK: - Actions
    
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
    
    @objc private func stageAllClicked(_ sender: NSButton) {
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
        updateCommitPlaceholder()
    }

    @objc private func amendCheckboxChanged(_ sender: NSButton) {
        if sender.state == .on {
            presenter?.didRequestLastCommitMessage()
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
            return splitView.bounds.width - 300 // Right pane (diff) min width
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

            // Badge container — provides padding around the text
            let badgeContainer = NSView()
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.cornerRadius = 4
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(badgeContainer)

            let statusBadge = NSTextField(labelWithString: "")
            statusBadge.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            statusBadge.alignment = .center
            statusBadge.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.addSubview(statusBadge)

            NSLayoutConstraint.activate([
                statusBadge.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
                statusBadge.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),
                statusBadge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            ])

            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 12)
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label

            NSLayoutConstraint.activate([
                badgeContainer.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                badgeContainer.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                badgeContainer.widthAnchor.constraint(equalToConstant: 24),
                badgeContainer.heightAnchor.constraint(equalToConstant: 18),

                label.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        if let textField = cell?.textField {
            textField.stringValue = file.path
        }

        // Locate the badge container (first NSView that is NOT the cell's textField)
        if let container = cell?.subviews.first(where: { !($0 is NSTextField) }),
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
        updateCommitPlaceholder()
    }
    
    private func updateCommitPlaceholder() {
        let isEmpty = commitTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let placeholder = commitTextView.enclosingScrollView?.subviews.first(where: { $0.identifier?.rawValue == "commitPlaceholder" }) {
            placeholder.isHidden = !isEmpty
        }
    }
    
    // MARK: - ChangesViewProtocol
    
    func showStagedFiles(_ files: [GitFileStatus]) {
        let previousSelection = stagedTableView.selectedRow >= 0 && stagedTableView.selectedRow < stagedFiles.count
            ? stagedFiles[stagedTableView.selectedRow].path : nil
        stagedFiles = files
        stagedTableView.reloadData()
        if let selected = previousSelection,
           let newIdx = files.firstIndex(where: { $0.path == selected }) {
            stagedTableView.selectRowIndexes(IndexSet(integer: newIdx), byExtendingSelection: false)
        }
    }
    
    func showUnstagedFiles(_ files: [GitFileStatus]) {
        let previousSelection = unstagedTableView.selectedRow >= 0 && unstagedTableView.selectedRow < unstagedFiles.count
            ? unstagedFiles[unstagedTableView.selectedRow].path : nil
        unstagedFiles = files
        unstagedTableView.reloadData()
        if let selected = previousSelection,
           let newIdx = files.firstIndex(where: { $0.path == selected }) {
            unstagedTableView.selectRowIndexes(IndexSet(integer: newIdx), byExtendingSelection: false)
        }
    }
    
    func showDiffText(_ text: String, for file: String, isStaged: Bool) {
        diffTitleLabel.stringValue = file
        isShowingUnstagedDiff = !isStaged
        let hunks = parseDiffHunks(from: text)
        diffLines = buildDiffLines(from: text, hunks: hunks)
        diffTableView.reloadData()
        if !diffLines.isEmpty {
            diffTableView.scrollRowToVisible(0)
        }
    }

    func showLastCommitMessage(_ message: String) {
        commitTextView.string = message
        updateCommitPlaceholder()
    }

    func showConflictBanner(_ hasConflicts: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            conflictBannerHeight.animator().constant = hasConflicts ? 36 : 0
        }
    }

    private func buildConflictBanner() -> NSView {
        let banner = NSView()
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor.gitFlowConflict.cgColor

        let icon = NSTextField(labelWithString: "⚠")
        icon.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        icon.textColor = NSColor.gitFlowConflictText
        icon.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(icon)

        let label = NSTextField(labelWithString: "Merge conflict — resolve conflicts and mark files as resolved, then commit")
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
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
        diffTitleLabel.stringValue = "No file selected"
        diffLines = []
        diffTableView.reloadData()
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
    
}
