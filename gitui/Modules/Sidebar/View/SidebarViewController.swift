// MARK: - SidebarViewController.swift

import Cocoa

protocol SidebarViewProtocol: AnyObject {
    func showBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?)
    func showLoading(_ loading: Bool)
}

// Wrapper classes to preserve pointer identity for NSOutlineView
class RepositoryItem: NSObject {
    var bookmark: RepositoryBookmark
    var groups: [Any]
    
    init(bookmark: RepositoryBookmark, groups: [Any] = []) {
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

class SubmoduleGroupItem: NSObject {
    let title = "Submodules"
    var items: [GitSubmodule]
    init(items: [GitSubmodule]) { self.items = items }
}

class WorktreeGroupItem: NSObject {
    let title = "Worktrees"
    var items: [GitWorktree]
    init(items: [GitWorktree]) { self.items = items }
}

class CustomSelectionRowView: NSTableRowView {
    var repositoryBackgroundColor: NSColor?

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        drawRepositoryBackground()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        drawRepositoryBackground()
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .normal
    }

    private func drawRepositoryBackground() {
        guard let repositoryBackgroundColor else { return }
        repositoryBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 2), xRadius: 6, yRadius: 6)
        path.fill()
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

class SidebarViewController: NSViewController, SidebarViewProtocol, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate, NSMenuDelegate {
    
    var presenter: SidebarPresenterProtocol?
    private var isSelectingProgrammatically = false
    
    private var repositoryItems: [RepositoryItem] = []
    private var activePath: String?
    private var lineStatsCache: [String: (added: Int, removed: Int)] = [:]
    
    // UI Elements
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet private weak var outlineView: NSOutlineView!
    @IBOutlet private weak var actionButton: NSButton!
    @IBOutlet private weak var removeButton: NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var segmentedControl: NSSegmentedControl!
    @IBOutlet private weak var bottomBorderView: NSView!
    
    private let dragType = NSPasteboard.PasteboardType("gitflow.sidebar.drag")
    private var currentTab: Int = 0 // 0 = Changes, 1 = Repositories
    private var currentSearchQuery: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
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
    
    private func configureUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.gitFlowSidebarBackground.cgColor

        bottomBorderView.wantsLayer = true
        bottomBorderView.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor

        segmentedControl.segmentCount = 2
        segmentedControl.setLabel("Changes", forSegment: 0)
        segmentedControl.setLabel("Repositories", forSegment: 1)
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged(_:))
        segmentedControl.selectedSegment = 0
        if #available(macOS 11.0, *) {
            segmentedControl.segmentStyle = .capsule
        } else {
            segmentedControl.segmentStyle = .texturedRounded
        }

        searchField.placeholderString = "Search branches, worktrees..."
        searchField.delegate = self
        searchField.font = NSFont.systemFont(ofSize: 12)
        outlineView.headerView = nil
        outlineView.backgroundColor = NSColor.clear
        outlineView.gridStyleMask = []
        outlineView.allowsMultipleSelection = false
        outlineView.selectionHighlightStyle = .regular
        outlineView.doubleAction = #selector(outlineDoubleClicked(_:))
        outlineView.registerForDraggedTypes([dragType])

        if let col = outlineView.tableColumns.first {
            col.identifier = NSUserInterfaceItemIdentifier("bookmarkColumn")
            outlineView.outlineTableColumn = col
        }

        outlineView.dataSource = self
        outlineView.delegate = self

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        outlineView.menu = contextMenu

        actionButton.image = NSImage(named: NSImage.addTemplateName)
        actionButton.target = self
        actionButton.action = #selector(plusClicked(_:))
        actionButton.bezelStyle = .texturedRounded
        actionButton.isBordered = false

        removeButton.image = NSImage(named: NSImage.removeTemplateName)
        removeButton.target = self
        removeButton.action = #selector(minusClicked(_:))
        removeButton.bezelStyle = .texturedRounded
        removeButton.isBordered = false
        removeButton.isEnabled = false

        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
    }
    
    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        currentTab = sender.selectedSegment
        actionButton.isHidden = (currentTab == 0)
        removeButton.isHidden = (currentTab == 0)
        
        searchField.placeholderString = currentTab == 0 ? "Search branches, worktrees..." : "Search repositories..."
        searchField.stringValue = ""
        currentSearchQuery = ""
        
        if currentTab == 1 {
            presenter?.filterBookmarks(query: "")
        }
        
        outlineView.reloadData()
        
        if currentTab == 0 {
            // Expand all groups in changes by default
            if let activeRepo = repositoryItems.first(where: { $0.bookmark.path == activePath }) {
                for group in activeRepo.groups {
                    outlineView.expandItem(group, expandChildren: true)
                }
            }
        }
    }
    
    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) else { return }

        if let repoItem = item as? RepositoryItem {
            let openTerminal = NSMenuItem(title: "Open in Terminal", action: #selector(contextOpenInTerminal(_:)), keyEquivalent: "")
            openTerminal.target = self
            openTerminal.representedObject = repoItem
            menu.addItem(openTerminal)

            let reveal = NSMenuItem(title: "Reveal in Finder", action: #selector(contextRevealInFinder(_:)), keyEquivalent: "")
            reveal.target = self
            reveal.representedObject = repoItem
            menu.addItem(reveal)

            let copyPath = NSMenuItem(title: "Copy Path", action: #selector(contextCopyPath(_:)), keyEquivalent: "")
            copyPath.target = self
            copyPath.representedObject = repoItem
            menu.addItem(copyPath)

            menu.addItem(.separator())

            let rename = NSMenuItem(title: "Rename...", action: #selector(contextRenameRepo(_:)), keyEquivalent: "")
            rename.target = self
            rename.representedObject = repoItem
            menu.addItem(rename)

            menu.addItem(.separator())

            let remove = NSMenuItem(title: "Remove from Sidebar", action: #selector(contextRemoveRepo(_:)), keyEquivalent: "")
            remove.target = self
            remove.representedObject = repoItem
            menu.addItem(remove)

        } else if let branchItem = item as? BranchItem {
            if !branchItem.branch.isCurrent {
                let switchBranch = NSMenuItem(title: "Switch to '\(branchItem.branch.shortName)'", action: #selector(contextSwitchBranch(_:)), keyEquivalent: "")
                switchBranch.target = self
                switchBranch.representedObject = branchItem
                menu.addItem(switchBranch)
                menu.addItem(.separator())
            }

            let copyName = NSMenuItem(title: "Copy Branch Name", action: #selector(contextCopyBranchName(_:)), keyEquivalent: "")
            copyName.target = self
            copyName.representedObject = branchItem
            menu.addItem(copyName)
        }
    }

    @objc private func contextOpenInTerminal(_ sender: NSMenuItem) {
        guard let repoItem = sender.representedObject as? RepositoryItem else { return }
        let url = URL(fileURLWithPath: repoItem.bookmark.path)
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                           configuration: NSWorkspace.OpenConfiguration(),
                                           completionHandler: nil)
        // Change Terminal's working directory via AppleScript
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(repoItem.bookmark.path)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
        _ = url
    }

    @objc private func contextRevealInFinder(_ sender: NSMenuItem) {
        guard let repoItem = sender.representedObject as? RepositoryItem else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repoItem.bookmark.path)
    }

    @objc private func contextCopyPath(_ sender: NSMenuItem) {
        guard let repoItem = sender.representedObject as? RepositoryItem else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(repoItem.bookmark.path, forType: .string)
    }

    @objc private func contextRenameRepo(_ sender: NSMenuItem) {
        guard let repoItem = sender.representedObject as? RepositoryItem else { return }
        guard let window = view.window else { return }

        let alert = NSAlert()
        alert.messageText = "Rename Repository"
        alert.informativeText = "Enter a new display name for '\(repoItem.bookmark.name)':"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        field.stringValue = repoItem.bookmark.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { return }
            self?.presenter?.didRenameRepository(repoItem.bookmark, newName: newName)
        }
    }

    @objc private func contextRemoveRepo(_ sender: NSMenuItem) {
        guard let repoItem = sender.representedObject as? RepositoryItem,
              let index = repositoryItems.firstIndex(of: repoItem) else { return }
        presenter?.didClickRemoveRepository(at: index)
    }

    @objc private func contextSwitchBranch(_ sender: NSMenuItem) {
        guard let branchItem = sender.representedObject as? BranchItem else { return }
        presenter?.didSelectBranch(branchItem.branch, in: branchItem.repoPath)
    }

    @objc private func contextCopyBranchName(_ sender: NSMenuItem) {
        guard let branchItem = sender.representedObject as? BranchItem else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branchItem.branch.shortName, forType: .string)
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
                presenter?.didSelectRepository(repoItem.bookmark)
            } else if let groupItem = clickedItem as? BranchGroupItem {
                if sender.isItemExpanded(groupItem) {
                    sender.animator().collapseItem(groupItem)
                } else {
                    sender.animator().expandItem(groupItem)
                }
            } else if let subGroup = clickedItem as? SubmoduleGroupItem {
                if sender.isItemExpanded(subGroup) {
                    sender.animator().collapseItem(subGroup)
                } else {
                    sender.animator().expandItem(subGroup)
                }
            } else if let wtGroup = clickedItem as? WorktreeGroupItem {
                if sender.isItemExpanded(wtGroup) {
                    sender.animator().collapseItem(wtGroup)
                } else {
                    sender.animator().expandItem(wtGroup)
                }
            } else if let branchItem = clickedItem as? BranchItem {
                presenter?.didSelectBranch(branchItem.branch, in: branchItem.repoPath)
            }
        }
    }
    
    // MARK: - Filtering Logic
    
    private func filteredGroups() -> [Any] {
        guard let activeRepo = repositoryItems.first(where: { $0.bookmark.path == activePath }) else { return [] }
        if currentSearchQuery.isEmpty { return activeRepo.groups }
        
        return activeRepo.groups.filter { group in
            if let bGroup = group as? BranchGroupItem {
                return !filteredBranches(for: bGroup).isEmpty
            } else if let sGroup = group as? SubmoduleGroupItem {
                return !filteredSubmodules(for: sGroup).isEmpty
            } else if let wGroup = group as? WorktreeGroupItem {
                return !filteredWorktrees(for: wGroup).isEmpty
            }
            return false
        }
    }
    
    private func filteredBranches(for group: BranchGroupItem) -> [BranchItem] {
        if currentSearchQuery.isEmpty { return group.branches }
        return group.branches.filter { $0.branch.shortName.lowercased().contains(currentSearchQuery) }
    }
    
    private func filteredSubmodules(for group: SubmoduleGroupItem) -> [GitSubmodule] {
        if currentSearchQuery.isEmpty { return group.items }
        return group.items.filter { $0.path.lowercased().contains(currentSearchQuery) }
    }
    
    private func filteredWorktrees(for group: WorktreeGroupItem) -> [GitWorktree] {
        if currentSearchQuery.isEmpty { return group.items }
        return group.items.filter { $0.branch.lowercased().contains(currentSearchQuery) || $0.path.lowercased().contains(currentSearchQuery) }
    }

    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if currentTab == 0 {
            if item == nil {
                return filteredGroups().count
            } else if let groupItem = item as? BranchGroupItem {
                return filteredBranches(for: groupItem).count
            } else if let subGroup = item as? SubmoduleGroupItem {
                return filteredSubmodules(for: subGroup).count
            } else if let wtGroup = item as? WorktreeGroupItem {
                return filteredWorktrees(for: wtGroup).count
            }
            return 0
        } else {
            if item == nil {
                return repositoryItems.count
            }
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if currentTab == 0 {
            if item == nil {
                return filteredGroups()[index]
            } else if let groupItem = item as? BranchGroupItem {
                return filteredBranches(for: groupItem)[index]
            } else if let subGroup = item as? SubmoduleGroupItem {
                return filteredSubmodules(for: subGroup)[index]
            } else if let wtGroup = item as? WorktreeGroupItem {
                return filteredWorktrees(for: wtGroup)[index]
            }
        } else {
            if item == nil {
                return repositoryItems[index]
            }
        }
        fatalError("Requested child out of bounds")
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if currentTab == 0 {
            if item is BranchGroupItem || item is SubmoduleGroupItem || item is WorktreeGroupItem {
                return true
            }
        } else {
            return false
        }
        return false
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if item is BranchGroupItem || item is SubmoduleGroupItem || item is WorktreeGroupItem {
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
        if let repoItem = item as? RepositoryItem, repoItem.bookmark.path == activePath {
            rowView?.repositoryBackgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15)
        } else {
            rowView?.repositoryBackgroundColor = nil
        }
        return rowView
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is RepositoryItem {
            return 58
        } else if item is BranchGroupItem || item is SubmoduleGroupItem || item is WorktreeGroupItem {
            return 24
        } else {
            return 28
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let repoItem = item as? RepositoryItem {
            let bookmark = repoItem.bookmark
            let isActive = bookmark.path == activePath
            
            var cell = outlineView.makeView(withIdentifier: SidebarRepositoryCellView.reuseIdentifier, owner: self) as? SidebarRepositoryCellView
            if cell == nil {
                cell = SidebarRepositoryCellView.instantiate()
            }

            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                cell?.repoIcon.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Repository")?.withSymbolConfiguration(config)
            }

            let showDivider = repositoryItems.firstIndex(of: repoItem).map { $0 > 0 } ?? false
            cell?.configure(
                bookmark: bookmark,
                isActive: isActive,
                stats: lineStatsCache[bookmark.path],
                showDivider: showDivider
            )
            return cell
        } else if item is BranchGroupItem || item is SubmoduleGroupItem || item is WorktreeGroupItem {
            var cell = outlineView.makeView(withIdentifier: SidebarGroupCellView.reuseIdentifier, owner: self) as? SidebarGroupCellView
            if cell == nil {
                cell = SidebarGroupCellView.instantiate()
            }

            let title: String
            let systemSymbolName: String?
            let fallbackImageName: String?
            let accessibilityDescription: String
            if let groupItem = item as? BranchGroupItem {
                title = groupItem.title.uppercased()
                if groupItem.title == "Remote Branches" {
                    systemSymbolName = "cloud"
                    fallbackImageName = nil
                    accessibilityDescription = "Remote branches"
                } else {
                    systemSymbolName = "arrow.triangle.branch"
                    fallbackImageName = NSImage.slideshowTemplateName
                    accessibilityDescription = "Local branches"
                }
            } else if let subGroup = item as? SubmoduleGroupItem {
                title = subGroup.title.uppercased()
                systemSymbolName = "shippingbox"
                fallbackImageName = nil
                accessibilityDescription = "Submodule group"
            } else if let wtGroup = item as? WorktreeGroupItem {
                title = wtGroup.title.uppercased()
                systemSymbolName = "folder"
                fallbackImageName = nil
                accessibilityDescription = "Worktree group"
            } else {
                title = ""
                systemSymbolName = nil
                fallbackImageName = nil
                accessibilityDescription = ""
            }

            cell?.configure(
                title: title,
                systemSymbolName: systemSymbolName,
                fallbackImageName: fallbackImageName,
                accessibilityDescription: accessibilityDescription
            )
            return cell
        } else if let branchItem = item as? BranchItem {
            let branch = branchItem.branch

            var cell = outlineView.makeView(withIdentifier: SidebarOutlineItemCellView.reuseIdentifier, owner: self) as? SidebarOutlineItemCellView
            if cell == nil {
                cell = SidebarOutlineItemCellView.instantiate()
            }

            cell?.configure(
                title: branch.shortName,
                systemSymbolName: nil,
                fallbackImageName: nil,
                accessibilityDescription: "Branch",
                font: branch.isCurrent
                    ? NSFont.systemFont(ofSize: 13, weight: .bold)
                    : NSFont.systemFont(ofSize: 13, weight: .medium),
                textColor: branch.isCurrent ? NSColor.gitFlowAccent : NSColor.labelColor,
                tintColor: branch.isCurrent ? NSColor.gitFlowAccent : NSColor.secondaryLabelColor
            )
            return cell
        } else if let subItem = item as? GitSubmodule {
            var cell = outlineView.makeView(withIdentifier: SidebarOutlineItemCellView.reuseIdentifier, owner: self) as? SidebarOutlineItemCellView
            if cell == nil {
                cell = SidebarOutlineItemCellView.instantiate()
            }

            cell?.configure(
                title: subItem.path,
                systemSymbolName: "shippingbox",
                fallbackImageName: nil,
                accessibilityDescription: "Submodule",
                font: NSFont.systemFont(ofSize: 13, weight: .medium),
                textColor: NSColor.labelColor,
                tintColor: NSColor.secondaryLabelColor
            )
            return cell
        } else if let wtItem = item as? GitWorktree {
            var cell = outlineView.makeView(withIdentifier: SidebarOutlineItemCellView.reuseIdentifier, owner: self) as? SidebarOutlineItemCellView
            if cell == nil {
                cell = SidebarOutlineItemCellView.instantiate()
            }

            cell?.configure(
                title: (wtItem.path as NSString).lastPathComponent + " (" + wtItem.branch + ")",
                systemSymbolName: "folder.badge.gearshape",
                fallbackImageName: nil,
                accessibilityDescription: "Worktree",
                font: NSFont.systemFont(ofSize: 13, weight: .medium),
                textColor: NSColor.labelColor,
                tintColor: NSColor.secondaryLabelColor
            )
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
        let query = field.stringValue
        
        if currentTab == 1 {
            presenter?.filterBookmarks(query: query)
        } else {
            currentSearchQuery = query.lowercased()
            outlineView.reloadData()
            
            if !query.isEmpty {
                // Expand all matching groups when searching
                for group in filteredGroups() {
                    outlineView.expandItem(group, expandChildren: true)
                }
            }
        }
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
        fetchSubmodulesAndWorktreesForAll()
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
                                if let existingLocal = targetItem.groups.first(where: { ($0 as? BranchGroupItem)?.title == "Local Branches" }) as? BranchGroupItem {
                                    existingLocal.branches = localBranches
                                    newGroups.append(existingLocal)
                                } else {
                                    newGroups.append(BranchGroupItem(title: "Local Branches", branches: localBranches))
                                }
                            }
                            
                            if !remoteBranches.isEmpty {
                                if let existingRemote = targetItem.groups.first(where: { ($0 as? BranchGroupItem)?.title == "Remote Branches" }) as? BranchGroupItem {
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
                            let expandedGroups = targetItem.groups.compactMap { group -> String? in
                                if let branchGroup = group as? BranchGroupItem { return branchGroup.title }
                                if let subGroup = group as? SubmoduleGroupItem { return subGroup.title }
                                if let wtGroup = group as? WorktreeGroupItem { return wtGroup.title }
                                return nil
                            }.filter { self.outlineView.isItemExpanded($0) }
                            
                            // Keep submodules/worktrees, replace branch groups
                            var updatedGroups: [Any] = newGroups
                            updatedGroups.append(contentsOf: targetItem.groups.filter { $0 is SubmoduleGroupItem || $0 is WorktreeGroupItem })
                            
                            targetItem.groups = updatedGroups
                            if path == self.activePath && self.currentTab == 0 {
                                self.outlineView.reloadData()
                            } else {
                                self.outlineView.reloadItem(targetItem, reloadChildren: true)
                            }

                            if path == self.activePath {
                                if self.currentTab == 0 {
                                    for group in updatedGroups {
                                        self.outlineView.expandItem(group, expandChildren: true)
                                    }
                                } else {
                                    self.outlineView.expandItem(targetItem, expandChildren: true)
                                }
                            } else {
                                for group in updatedGroups {
                                    let title: String?
                                    if let bGroup = group as? BranchGroupItem { title = bGroup.title }
                                    else if let sGroup = group as? SubmoduleGroupItem { title = sGroup.title }
                                    else if let wGroup = group as? WorktreeGroupItem { title = wGroup.title }
                                    else { title = nil }

                                    if let t = title, expandedGroups.contains(t) {
                                        self.outlineView.expandItem(group)
                                    }
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
    func fetchSubmodulesAndWorktreesForAll() {
        for item in repositoryItems {
            let path = item.bookmark.path
            Task {
                do {
                    let submodules = try await GitSubmoduleService.shared.getSubmodules(in: path)
                    let worktrees = try await GitWorktreeService.shared.getWorktrees(in: path)
                    await MainActor.run {
                        if let targetItem = self.repositoryItems.first(where: { $0.bookmark.path == path }) {
                            // Keep branches, add submodules/worktrees
                            var newGroups: [Any] = targetItem.groups.filter { $0 is BranchGroupItem }
                            
                            if !submodules.isEmpty {
                                newGroups.append(SubmoduleGroupItem(items: submodules))
                            }
                            if !worktrees.isEmpty {
                                newGroups.append(WorktreeGroupItem(items: worktrees))
                            }
                            
                            targetItem.groups = newGroups
                            if path == self.activePath && self.currentTab == 0 {
                                self.outlineView.reloadData()
                            } else {
                                self.outlineView.reloadItem(targetItem, reloadChildren: true)
                            }

                            if path == self.activePath {
                                if self.currentTab == 0 {
                                    for group in newGroups {
                                        self.outlineView.expandItem(group, expandChildren: true)
                                    }
                                } else {
                                    self.outlineView.expandItem(targetItem, expandChildren: true)
                                }
                            }
                        }
                    }
                } catch {
                    // Ignore
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
