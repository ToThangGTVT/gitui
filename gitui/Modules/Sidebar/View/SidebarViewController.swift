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
    override func drawSelection(in dirtyRect: NSRect) {
        // Selection background is handled by the cell's own layer
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .normal
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
    private var searchField: NSSearchField!
    private var outlineView: NSOutlineView!
    private var actionButton: NSButton!
    private var removeButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var segmentedControl: NSSegmentedControl!
    
    private let dragType = NSPasteboard.PasteboardType("gitflow.sidebar.drag")
    private var backgroundView: NSView!
    private var currentTab: Int = 0 // 0 = Changes, 1 = Repositories
    private var searchContainer: NSView!
    private var currentSearchQuery: String = ""
    
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
        // Solid sidebar using NSView with M3 surface color
        backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.gitFlowSidebarBackground.cgColor
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // 0. Segmented Control at Top
        let tabContainer = NSView()
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(tabContainer)
        
        segmentedControl = NSSegmentedControl(labels: ["Changes", "Repositories"], trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
        segmentedControl.selectedSegment = 0
        if #available(macOS 11.0, *) {
            segmentedControl.segmentStyle = .capsule
        } else {
            segmentedControl.segmentStyle = .texturedRounded
        }
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(segmentedControl)
        
        // 1. Search Bar at Top
        searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(searchContainer)
        
        searchField = NSSearchField()
        searchField.placeholderString = "Search branches, worktrees..."
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
        backgroundView.addSubview(scroll)
        
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.backgroundColor = NSColor.clear
        outlineView.gridStyleMask = []
        outlineView.allowsMultipleSelection = false
        outlineView.selectionHighlightStyle = .none
        outlineView.doubleAction = #selector(outlineDoubleClicked(_:))
        
        // Register drag & drop
        outlineView.registerForDraggedTypes([dragType])
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bookmarkColumn"))
        col.width = 200
        outlineView.addTableColumn(col)
        
        outlineView.dataSource = self
        outlineView.delegate = self
        scroll.documentView = outlineView

        let contextMenu = NSMenu()
        contextMenu.delegate = self
        outlineView.menu = contextMenu
        
        // 3. Bottom Bar
        let bottomView = NSView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(bottomView)
        
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
        backgroundView.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            tabContainer.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            tabContainer.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            tabContainer.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            tabContainer.heightAnchor.constraint(equalToConstant: 44),
            
            segmentedControl.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            segmentedControl.centerXAnchor.constraint(equalTo: tabContainer.centerXAnchor),
            
            searchContainer.topAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 32),
            
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            
            scroll.topAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            
            bottomView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
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
            
            let cellIdentifier = NSUserInterfaceItemIdentifier("BookmarkCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier

                let icon = NSImageView()
                if #available(macOS 11.0, *) {
                    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                    icon.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Repository")?.withSymbolConfiguration(config)
                }
                icon.imageScaling = .scaleProportionallyUpOrDown
                icon.identifier = NSUserInterfaceItemIdentifier("repoIcon")
                icon.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(icon)
                cell?.imageView = icon

                let label = NSTextField(labelWithString: "")
                label.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(label)
                cell?.textField = label

                let divider = NSView()
                divider.wantsLayer = true
                divider.layer?.backgroundColor = NSColor.gitFlowBorder.withAlphaComponent(0.4).cgColor
                divider.identifier = NSUserInterfaceItemIdentifier("repoDivider")
                divider.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(divider)

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
                    divider.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 16),
                    divider.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -16),
                    divider.topAnchor.constraint(equalTo: cell!.topAnchor),
                    divider.heightAnchor.constraint(equalToConstant: 1),

                    icon.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                    icon.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 15),
                    icon.heightAnchor.constraint(equalToConstant: 15),

                    label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
                    label.bottomAnchor.constraint(equalTo: cell!.centerYAnchor, constant: 1),

                    statsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 4),
                    statsLabel.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    statsLabel.centerYAnchor.constraint(equalTo: label.centerYAnchor),

                    pathLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
                    pathLabel.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    pathLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2)
                ])
            }
            
            cell?.wantsLayer = true
            cell?.layer?.cornerRadius = 6
            if isActive {
                cell?.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
            } else {
                cell?.layer?.backgroundColor = NSColor.clear.cgColor
            }

            if #available(macOS 11.0, *),
               let icon = cell?.subviews.first(where: { $0.identifier?.rawValue == "repoIcon" }) as? NSImageView {
                icon.contentTintColor = isActive ? NSColor.gitFlowAccent : NSColor.secondaryLabelColor
            }

            if let textField = cell?.textField {
                textField.stringValue = bookmark.name
                if isActive {
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
            
            if let divider = cell?.subviews.first(where: { $0.identifier?.rawValue == "repoDivider" }) {
                if let index = repositoryItems.firstIndex(of: repoItem), index > 0 {
                    divider.isHidden = false
                } else {
                    divider.isHidden = true
                }
            }
            
            return cell
        } else if item is BranchGroupItem || item is SubmoduleGroupItem || item is WorktreeGroupItem {
            let cellIdentifier = NSUserInterfaceItemIdentifier("GroupCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                let label = NSTextField(labelWithString: "")
                label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                label.textColor = NSColor.secondaryLabelColor
                label.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(label)
                cell?.textField = label
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                    label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
            if let groupItem = item as? BranchGroupItem {
                cell?.textField?.stringValue = groupItem.title.uppercased()
            } else if let subGroup = item as? SubmoduleGroupItem {
                cell?.textField?.stringValue = subGroup.title.uppercased()
            } else if let wtGroup = item as? WorktreeGroupItem {
                cell?.textField?.stringValue = wtGroup.title.uppercased()
            }
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
                    textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                    textField.textColor = NSColor.labelColor
                    if #available(macOS 11.0, *) {
                        cell?.imageView?.contentTintColor = NSColor.secondaryLabelColor
                    }
                }
            }
            
            return cell
        } else if let subItem = item as? GitSubmodule {
            let cellIdentifier = NSUserInterfaceItemIdentifier("SubmoduleCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                
                let icon = NSImageView()
                if #available(macOS 11.0, *) {
                    icon.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Submodule")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .medium))
                    icon.contentTintColor = NSColor.secondaryLabelColor
                }
                icon.imageScaling = .scaleProportionallyUpOrDown
                icon.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(icon)
                cell?.imageView = icon
                
                let label = NSTextField(labelWithString: "")
                label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                label.textColor = NSColor.labelColor
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
            cell?.textField?.stringValue = subItem.path
            return cell
        } else if let wtItem = item as? GitWorktree {
            let cellIdentifier = NSUserInterfaceItemIdentifier("WorktreeCell")
            var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = cellIdentifier
                
                let icon = NSImageView()
                if #available(macOS 11.0, *) {
                    icon.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Worktree")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .medium))
                    icon.contentTintColor = NSColor.secondaryLabelColor
                }
                icon.imageScaling = .scaleProportionallyUpOrDown
                icon.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(icon)
                cell?.imageView = icon
                
                let label = NSTextField(labelWithString: "")
                label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                label.textColor = NSColor.labelColor
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
            cell?.textField?.stringValue = (wtItem.path as NSString).lastPathComponent + " (" + wtItem.branch + ")"
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
