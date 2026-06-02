// MARK: - SidebarViewController.swift

import Cocoa

protocol SidebarViewProtocol: AnyObject {
    func showBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?)
    func showLoading(_ loading: Bool)
}

// Wrapper classes to preserve pointer identity for NSOutlineView
class RepositoryItem: NSObject {
    var bookmark: RepositoryBookmark
    var groups: [BranchGroupItem]
    
    init(bookmark: RepositoryBookmark, groups: [BranchGroupItem] = []) {
        self.bookmark = bookmark
        self.groups = groups
    }
}

class BranchGroupItem: NSObject {
    let title: String
    var branches: [BranchItem]
    
    init(title: String, branches: [BranchItem]) {
        self.title = title
        self.branches = branches
    }
}

class CustomSelectionRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            let selectionRect = self.bounds.insetBy(dx: 6, dy: 0) // Standard macOS padding
            
            let bgColor = NSColor.systemBlue.withAlphaComponent(0.2)
            bgColor.setFill()
            
            // Standard rounded corner, not a full pill
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            path.fill()
        }
    }
}

class BranchItem: NSObject {
    let branch: GitBranch
    let repoPath: String
    
    init(branch: GitBranch, repoPath: String) {
        self.branch = branch
        self.repoPath = repoPath
    }
}

class SidebarViewController: NSViewController, SidebarViewProtocol, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate {
    
    var presenter: SidebarPresenterProtocol?
    private var isSelectingProgrammatically = false
    
    private var repositoryItems: [RepositoryItem] = []
    private var activePath: String?
    private var lineStatsCache: [String: (added: Int, removed: Int)] = [:]
    
    // UI Elements
    private var searchField: NSSearchField!
    private var outlineView: NSOutlineView!
    private var actionButton: NSButton!
    private var removeButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    private let dragType = NSPasteboard.PasteboardType("gitflow.sidebar.drag")
    private var visualEffectView: NSVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRefreshStats), name: .sidebarShouldRefreshStats, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleRefreshStats() {
        fetchLineStatsForAll()
        fetchBranchesForAll()
    }
    
    private func setupUI() {
        // Translucent sidebar using NSVisualEffectView
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .followsWindowActiveState
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // 1. Search Bar at Top
        let searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(searchContainer)
        
        searchField = NSSearchField()
        searchField.placeholderString = "Search repositories..."
        searchField.delegate = self
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)
        
        // 2. Outline Scroll View
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(scroll)
        
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.backgroundColor = NSColor.clear
        outlineView.gridStyleMask = []
        outlineView.allowsMultipleSelection = false
        outlineView.doubleAction = #selector(outlineDoubleClicked(_:))
        
        // Register drag & drop
        outlineView.registerForDraggedTypes([dragType])
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bookmarkColumn"))
        col.width = 200
        outlineView.addTableColumn(col)
        
        outlineView.dataSource = self
        outlineView.delegate = self
        scroll.documentView = outlineView
        
        // 3. Bottom Bar
        let bottomView = NSView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(bottomView)
        
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(border)
        
        actionButton = NSButton(image: NSImage(named: NSImage.addTemplateName)!, target: self, action: #selector(plusClicked(_:)))
        actionButton.bezelStyle = .texturedRounded
        actionButton.isBordered = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(actionButton)
        
        removeButton = NSButton(image: NSImage(named: NSImage.removeTemplateName)!, target: self, action: #selector(minusClicked(_:)))
        removeButton.bezelStyle = .texturedRounded
        removeButton.isBordered = false
        removeButton.isEnabled = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(removeButton)
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),
            
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            
            scroll.topAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            
            bottomView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 40),
            
            border.topAnchor.constraint(equalTo: bottomView.topAnchor),
            border.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            actionButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            actionButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 12),
            actionButton.widthAnchor.constraint(equalToConstant: 24),
            actionButton.heightAnchor.constraint(equalToConstant: 24),
            
            removeButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: actionButton.trailingAnchor, constant: 8),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
            removeButton.heightAnchor.constraint(equalToConstant: 24),
            
            progressIndicator.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -12),
            progressIndicator.widthAnchor.constraint(equalToConstant: 14),
            progressIndicator.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func plusClicked(_ sender: NSButton) {
        let menu = NSMenu()
        
        let cloneItem = NSMenuItem(title: "Clone Repository...", action: #selector(menuCloneClicked(_:)), keyEquivalent: "")
        cloneItem.target = self
        menu.addItem(cloneItem)
        
        let openItem = NSMenuItem(title: "Open Existing Repository...", action: #selector(menuOpenClicked(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        let initItem = NSMenuItem(title: "Initialize New Repository...", action: #selector(menuInitClicked(_:)), keyEquivalent: "")
        initItem.target = self
        menu.addItem(initItem)
        
        let point = NSPoint(x: sender.frame.minX, y: sender.frame.maxY + 5)
        menu.popUp(positioning: nil, at: point, in: sender.superview)
    }
    
    @objc private func menuCloneClicked(_ sender: NSMenuItem) {
        presenter?.didClickClone()
    }
    
    @objc private func menuOpenClicked(_ sender: NSMenuItem) {
        presenter?.didClickOpen()
    }
    
    @objc private func menuInitClicked(_ sender: NSMenuItem) {
        presenter?.didClickInit()
    }
    
    @objc private func minusClicked(_ sender: NSButton) {
        let row = outlineView.selectedRow
        guard row >= 0 else { return }
        if let repoItem = outlineView.item(atRow: row) as? RepositoryItem,
           let index = repositoryItems.firstIndex(of: repoItem) {
            presenter?.didClickRemoveRepository(at: index)
        }
    }
    
    @objc private func outlineDoubleClicked(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0 else { return }
        
        if let clickedItem = sender.item(atRow: row) {
            if let repoItem = clickedItem as? RepositoryItem {
                if sender.isItemExpanded(repoItem) {
                    sender.animator().collapseItem(repoItem)
                } else {
                    sender.animator().expandItem(repoItem)
                }
            } else if let groupItem = clickedItem as? BranchGroupItem {
                if sender.isItemExpanded(groupItem) {
                    sender.animator().collapseItem(groupItem)
                } else {
                    sender.animator().expandItem(groupItem)
                }
            } else if let branchItem = clickedItem as? BranchItem {
                presenter?.didSelectBranch(branchItem.branch, in: branchItem.repoPath)
            }
        }
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return repositoryItems.count
        } else if let repoItem = item as? RepositoryItem {
            return repoItem.groups.count
        } else if let groupItem = item as? BranchGroupItem {
            return groupItem.branches.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return repositoryItems[index]
        } else if let repoItem = item as? RepositoryItem {
            return repoItem.groups[index]
        } else if let groupItem = item as? BranchGroupItem {
            return groupItem.branches[index]
        }
        fatalError("Requested child out of bounds")
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is RepositoryItem {
            return true
        } else if item is BranchGroupItem {
            return true
        }
        return false
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if item is BranchGroupItem {
            return false
        }
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("CustomRowView")
        var rowView = outlineView.makeView(withIdentifier: identifier, owner: self) as? CustomSelectionRowView
        if rowView == nil {
            rowView = CustomSelectionRowView()
            rowView?.identifier = identifier
        }
        return rowView
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is RepositoryItem {
            return 46
        } else if item is BranchGroupItem {
            return 24
        } else {
            return 28
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let repoItem = item as? RepositoryItem {
            let bookmark = repoItem.bookmark
            let isActive = bookmark.path == activePath
            
            let cellIdentifier = NSUserInterfaceItemIdentifier("BookmarkCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                

                
                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(label)
                cell?.textField = label
                
                let pathLabel = NSTextField(labelWithString: "")
                pathLabel.font = NSFont.systemFont(ofSize: 10)
                pathLabel.textColor = NSColor.secondaryLabelColor
                pathLabel.lineBreakMode = .byTruncatingHead
                pathLabel.identifier = NSUserInterfaceItemIdentifier("pathLabel")
                pathLabel.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(pathLabel)
                
                let statsLabel = NSTextField(labelWithString: "")
                statsLabel.font = NSFont(name: "SF Mono", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                statsLabel.identifier = NSUserInterfaceItemIdentifier("statsLabel")
                statsLabel.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(statsLabel)
                
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                    label.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 8),
                    
                    statsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 4),
                    statsLabel.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    statsLabel.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                    
                    pathLabel.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                    pathLabel.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    pathLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2)
                ])
            }
            
            if let textField = cell?.textField {
                textField.stringValue = bookmark.name
                if isActive {
                    // M3 'On Secondary Container' equivalent (bold, distinct color)
                    textField.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
                    textField.textColor = NSColor.m3Primary
                } else {
                    textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                    textField.textColor = NSColor.labelColor
                }
            }
            
            if let pathLabel = cell?.subviews.first(where: { $0.identifier?.rawValue == "pathLabel" }) as? NSTextField {
                pathLabel.stringValue = bookmark.path
                pathLabel.textColor = isActive ? NSColor.gitFlowAccent.withAlphaComponent(0.7) : NSColor.secondaryLabelColor
            }
            
            if let statsLabel = cell?.subviews.first(where: { $0.identifier?.rawValue == "statsLabel" }) as? NSTextField {
                if let stats = lineStatsCache[bookmark.path], (stats.added > 0 || stats.removed > 0) {
                    let result = NSMutableAttributedString()
                    if stats.added > 0 {
                        result.append(NSAttributedString(string: "+\(stats.added)", attributes: [
                            .foregroundColor: NSColor.gitFlowStagedAddText,
                            .font: NSFont(name: "SF Mono", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                        ]))
                    }
                    if stats.added > 0 && stats.removed > 0 {
                        result.append(NSAttributedString(string: " ", attributes: [
                            .font: NSFont.systemFont(ofSize: 11)
                        ]))
                    }
                    if stats.removed > 0 {
                        result.append(NSAttributedString(string: "-\(stats.removed)", attributes: [
                            .foregroundColor: NSColor.gitFlowStagedDeleteText,
                            .font: NSFont(name: "SF Mono", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                        ]))
                    }
                    statsLabel.attributedStringValue = result
                } else {
                    statsLabel.stringValue = ""
                }
            }
            
            return cell
        } else if let groupItem = item as? BranchGroupItem {
            let cellIdentifier = NSUserInterfaceItemIdentifier("GroupCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                let label = NSTextField(labelWithString: "")
                label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                label.textColor = NSColor.tertiaryLabelColor
                label.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(label)
                cell?.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                    label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
            cell?.textField?.stringValue = groupItem.title.uppercased()
            return cell
        } else if let branchItem = item as? BranchItem {
            let branch = branchItem.branch
            
            let cellIdentifier = NSUserInterfaceItemIdentifier("BranchCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                
                let icon = NSImageView()
                if #available(macOS 11.0, *) {
                    let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
                    icon.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Branch")?.withSymbolConfiguration(config)
                } else {
                    icon.image = NSImage(named: NSImage.slideshowTemplateName)
                }
                icon.imageScaling = .scaleProportionallyUpOrDown
                icon.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(icon)
                cell?.imageView = icon
                
                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(label)
                cell?.textField = label
                
                NSLayoutConstraint.activate([
                    icon.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                    icon.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 12),
                    icon.heightAnchor.constraint(equalToConstant: 12),
                    
                    label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                    label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8)
                ])
            }
            
            if let textField = cell?.textField {
                textField.stringValue = branch.shortName
                if branch.isCurrent {
                    textField.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                    textField.textColor = NSColor.gitFlowAccent
                    if #available(macOS 11.0, *) {
                        cell?.imageView?.contentTintColor = NSColor.gitFlowAccent
                    }
                } else {
                    textField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
                    textField.textColor = NSColor.labelColor
                    if #available(macOS 11.0, *) {
                        cell?.imageView?.contentTintColor = NSColor.secondaryLabelColor
                    }
                }
            }
            
            return cell
        }
        
        return nil
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        if isSelectingProgrammatically { return }
        
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0 else {
            removeButton.isEnabled = false
            return
        }
        
        if let selectedItem = outlineView.item(atRow: selectedRow) {
            if let repoItem = selectedItem as? RepositoryItem {
                removeButton.isEnabled = true
                presenter?.didSelectRepository(repoItem.bookmark)
            } else if let branchItem = selectedItem as? BranchItem {
                removeButton.isEnabled = false
                if branchItem.repoPath != activePath {
                    if let parentRepo = repositoryItems.first(where: { $0.bookmark.path == branchItem.repoPath }) {
                        presenter?.didSelectRepository(parentRepo.bookmark)
                    }
                }
            }
        }
    }
    
    // MARK: - Drag & Drop Reordering
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let repoItem = item as? RepositoryItem,
              let index = repositoryItems.firstIndex(of: repoItem) else { return nil }
        
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(String(index), forType: dragType)
        return pasteboardItem
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        // Only allow dropping at root level above another repository
        if item == nil && index != NSOutlineViewDropOnItemIndex {
            return .move
        }
        return []
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard item == nil,
              let draggingItem = info.draggingPasteboard.pasteboardItems?.first,
              let strValue = draggingItem.string(forType: dragType),
              let sourceIndex = Int(strValue) else { return false }
        
        presenter?.didMoveRepository(from: sourceIndex, to: index)
        return true
    }
    
    // MARK: - NSSearchFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        presenter?.filterBookmarks(query: field.stringValue)
    }
    
    // MARK: - SidebarViewProtocol
    
    func showBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?) {
        self.activePath = activePath
        
        // Re-use or rebuild repositoryItems to preserve expansion state
        let existingMap = Dictionary(uniqueKeysWithValues: self.repositoryItems.map { ($0.bookmark.path, $0) })
        self.repositoryItems = bookmarks.map { bookmark in
            if let existing = existingMap[bookmark.path] {
                existing.bookmark = bookmark
                return existing
            } else {
                return RepositoryItem(bookmark: bookmark)
            }
        }
        
        // Save currently selected item
        var itemToSelect: Any?
        if outlineView.selectedRow >= 0 {
            itemToSelect = outlineView.item(atRow: outlineView.selectedRow)
        }
        
        outlineView.reloadData()
        
        // Restore selection if exists, else select active repo
        var didRestore = false
        if let item = itemToSelect {
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                isSelectingProgrammatically = true
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                isSelectingProgrammatically = false
                didRestore = true
            }
        }
        
        // Natively select the active item so CustomSelectionRowView can draw the background
        if !didRestore, let active = activePath,
           let targetItem = repositoryItems.first(where: { $0.bookmark.path == active }) {
            let row = outlineView.row(forItem: targetItem)
            if row >= 0 {
                isSelectingProgrammatically = true
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                isSelectingProgrammatically = false
            }
        }
        
        removeButton.isEnabled = false
        fetchLineStatsForAll()
        fetchBranchesForAll()
    }
    
    private func fetchLineStatsForAll() {
        for item in repositoryItems {
            let path = item.bookmark.path
            Task {
                do {
                    let stats = try await GitService.shared.getLineStats(in: path)
                    await MainActor.run {
                        self.lineStatsCache[path] = stats
                        if let targetItem = self.repositoryItems.first(where: { $0.bookmark.path == path }) {
                            self.outlineView.reloadItem(targetItem, reloadChildren: false)
                        }
                    }
                } catch {
                    // Silently ignore
                }
            }
        }
    }
    
    private func fetchBranchesForAll() {
        for item in repositoryItems {
            let path = item.bookmark.path
            Task {
                do {
                    let branches = try await GitService.shared.getBranches(in: path)
                    await MainActor.run {
                        if let targetItem = self.repositoryItems.first(where: { $0.bookmark.path == path }) {
                            let localBranches = branches.filter { !$0.isRemote }.map { BranchItem(branch: $0, repoPath: path) }
                            let remoteBranches = branches.filter { $0.isRemote }.map { BranchItem(branch: $0, repoPath: path) }
                            
                            // Preserve expansion state by updating existing groups
                            var newGroups: [BranchGroupItem] = []
                            
                            if !localBranches.isEmpty {
                                if let existingLocal = targetItem.groups.first(where: { $0.title == "Local Branches" }) {
                                    existingLocal.branches = localBranches
                                    newGroups.append(existingLocal)
                                } else {
                                    newGroups.append(BranchGroupItem(title: "Local Branches", branches: localBranches))
                                }
                            }
                            
                            if !remoteBranches.isEmpty {
                                if let existingRemote = targetItem.groups.first(where: { $0.title == "Remote Branches" }) {
                                    existingRemote.branches = remoteBranches
                                    newGroups.append(existingRemote)
                                } else {
                                    newGroups.append(BranchGroupItem(title: "Remote Branches", branches: remoteBranches))
                                }
                            }
                            
                            // Save currently selected branch in this repo if any
                            var selectedBranchItem: BranchItem?
                            if self.outlineView.selectedRow >= 0,
                               let currentItem = self.outlineView.item(atRow: self.outlineView.selectedRow) as? BranchItem,
                               currentItem.repoPath == path {
                                selectedBranchItem = currentItem
                            }
                            
                            // Save expansion states of the groups before reloading
                            let expandedGroups = targetItem.groups.filter { self.outlineView.isItemExpanded($0) }.map { $0.title }
                            
                            targetItem.groups = newGroups
                            self.outlineView.reloadItem(targetItem, reloadChildren: true)
                            
                            // Re-expand groups
                            for group in newGroups {
                                if expandedGroups.contains(group.title) {
                                    self.outlineView.expandItem(group)
                                }
                            }
                            
                            // Restore branch selection
                            if let oldBranch = selectedBranchItem {
                                // Find equivalent new branch
                                if let newGroup = newGroups.first(where: { group in group.branches.contains(where: { $0.branch.name == oldBranch.branch.name }) }),
                                   let newBranch = newGroup.branches.first(where: { $0.branch.name == oldBranch.branch.name }) {
                                    let row = self.outlineView.row(forItem: newBranch)
                                    if row >= 0 {
                                        self.isSelectingProgrammatically = true
                                        self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                                        self.isSelectingProgrammatically = false
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    // Ignore error - folder might not exist or not be a git repo
                }
            }
        }
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
