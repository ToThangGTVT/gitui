// MARK: - ChangesViewController.swift

import Cocoa

protocol ChangesViewProtocol: AnyObject {
    func showStagedFiles(_ files: [GitFileStatus])
    func showUnstagedFiles(_ files: [GitFileStatus])
    func showDiffText(_ text: String, for file: String)
    func clearDiff()
    func showLoading(_ loading: Bool)
}

// MARK: - Pane minimum heights & UserDefaults keys

private enum FilesSplitMin {
    static let staged:   CGFloat = 80
    static let unstaged: CGFloat = 80
    static let commit:   CGFloat = 100
    static var total:    CGFloat { staged + unstaged + commit }
}

private enum FilesSplitKey {
    static let divider0 = "gitflow.changes.files.divider0"
    static let divider1 = "gitflow.changes.files.divider1"
}

class ChangesViewController: NSViewController, ChangesViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSplitViewDelegate {
    
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
    private var diffTextView: NSTextView!
    private var diffScrollView: NSScrollView!
    private var diffTitleLabel: NSTextField!
    
    // Commit Box Components
    private var commitTextView: NSTextView!
    private var commitButton: NSButton!
    private var stageAllButton: NSButton!
    private var unstageAllButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    private var hasRestoredMainSplit = false
    private var hasRestoredLeftSplit = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
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
        
        // 2. Setup Left Split View (Vertical: Staged, Unstaged, Commit Box)
        leftSplitView = NSSplitView()
        leftSplitView.isVertical = false
        leftSplitView.dividerStyle = .thin
        leftSplitView.delegate = self
        leftSplitView.pinToEdges(of: leftContainer)
        
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
        
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor.secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
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
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            
            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
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
        commitTextView.string = "Commit message..."
        scroll.documentView = commitTextView
        
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
            scroll.bottomAnchor.constraint(equalTo: commitButton.topAnchor, constant: -10),
            
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
        diffScrollView.borderType = .noBorder
        diffScrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(diffScrollView)
        
        diffTextView = NSTextView()
        diffTextView.isRichText = false
        diffTextView.isEditable = false
        diffTextView.font = NSFont(name: "Menlo", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)
        diffTextView.textColor = NSColor.labelColor
        diffTextView.backgroundColor = NSColor.controlBackgroundColor
        diffTextView.isHorizontallyResizable = true
        diffTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        diffTextView.textContainer?.widthTracksTextView = false
        diffTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        diffScrollView.documentView = diffTextView
        
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
        let message = commitTextView.string == "Commit message..." ? "" : commitTextView.string
        presenter?.didClickCommit(message: message)
        commitTextView.string = "Commit message..."
        commitTextView.textColor = NSColor.placeholderTextColor
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
        if tableView === stagedTableView {
            return stagedFiles.count
        } else {
            return unstagedFiles.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = tableView === stagedTableView ? stagedFiles[row] : unstagedFiles[row]
        
        let identifier = NSUserInterfaceItemIdentifier("fileCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            
            let statusBadge = NSTextField(labelWithString: "")
            statusBadge.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            statusBadge.alignment = .center
            statusBadge.wantsLayer = true
            statusBadge.layer?.cornerRadius = 3
            statusBadge.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(statusBadge)
            
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 12)
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            NSLayoutConstraint.activate([
                statusBadge.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                statusBadge.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                statusBadge.widthAnchor.constraint(equalToConstant: 18),
                statusBadge.heightAnchor.constraint(equalToConstant: 16),
                
                label.leadingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        // Configure cell elements
        if let textField = cell?.textField {
            textField.stringValue = file.path
        }
        
        if let badge = cell?.subviews.first(where: { $0 is NSTextField && $0 !== cell?.textField }) as? NSTextField {
            badge.stringValue = file.status
            if file.status == "A" || file.status == "?" {
                badge.textColor = NSColor.gitFlowStagedAddText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor
            } else if file.status == "D" {
                badge.textColor = NSColor.gitFlowStagedDeleteText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor
            } else {
                badge.textColor = NSColor.gitFlowAccent
                badge.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
            }
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }
        
        if table === stagedTableView {
            unstagedTableView.deselectAll(nil)
            presenter?.didSelectFile(stagedFiles[row])
        } else {
            stagedTableView.deselectAll(nil)
            presenter?.didSelectFile(unstagedFiles[row])
        }
    }
    
    // MARK: - NSTextViewDelegate placeholder simulation
    
    func textViewDidBeginEditing(_ notification: Notification) {
        if commitTextView.string == "Commit message..." {
            commitTextView.string = ""
            commitTextView.textColor = NSColor.labelColor
        }
    }
    
    func textViewDidEndEditing(_ notification: Notification) {
        if commitTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commitTextView.string = "Commit message..."
            commitTextView.textColor = NSColor.placeholderTextColor
        }
    }
    
    // MARK: - ChangesViewProtocol
    
    func showStagedFiles(_ files: [GitFileStatus]) {
        stagedFiles = files
        stagedTableView.reloadData()
    }
    
    func showUnstagedFiles(_ files: [GitFileStatus]) {
        unstagedFiles = files
        unstagedTableView.reloadData()
    }
    
    func showDiffText(_ text: String, for file: String) {
        diffTitleLabel.stringValue = file
        
        // Generate premium visual HSL highlighting for the diff code!
        let highlighted = highlightDiffText(text)
        diffTextView.textStorage?.setAttributedString(highlighted)
    }
    
    func clearDiff() {
        diffTitleLabel.stringValue = "No file selected"
        diffTextView.string = ""
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
    
    private func highlightDiffText(_ text: String) -> NSAttributedString {
        let font = NSFont(name: "SF Mono", size: 11) ?? NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11)!
        let attrStr = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        
        let lines = text.components(separatedBy: .newlines)
        var currentOffset = 0
        
        for line in lines {
            let lineRange = NSRange(location: currentOffset, length: line.count)
            if line.hasPrefix("+") {
                attrStr.addAttribute(.backgroundColor, value: NSColor.gitFlowStagedAdd, range: lineRange)
                attrStr.addAttribute(.foregroundColor, value: NSColor.gitFlowStagedAddText, range: lineRange)
            } else if line.hasPrefix("-") {
                attrStr.addAttribute(.backgroundColor, value: NSColor.gitFlowStagedDelete, range: lineRange)
                attrStr.addAttribute(.foregroundColor, value: NSColor.gitFlowStagedDeleteText, range: lineRange)
            } else if line.hasPrefix("@@") {
                attrStr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
            } else if line.hasPrefix("diff") || line.hasPrefix("index") || line.hasPrefix("---") || line.hasPrefix("+++") {
                attrStr.addAttribute(.foregroundColor, value: NSColor.gitFlowAccent, range: lineRange)
            }
            currentOffset += line.count + 1
        }
        
        return attrStr
    }
}
