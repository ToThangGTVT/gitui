// MARK: - BranchesViewController.swift

import Cocoa

protocol BranchesViewProtocol: AnyObject {
    func showBranchTree(_ roots: [BranchNode])
    func showLoading(_ loading: Bool)
}

class BranchesViewController: NSViewController, BranchesViewProtocol, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    var presenter: BranchesPresenterProtocol?
    
    private var treeRoots: [BranchNode] = []
    
    // UI Elements
    private var outlineView: NSOutlineView!
    private var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.pinToEdges(of: view)
        
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.backgroundColor = NSColor.controlBackgroundColor
        outlineView.rowHeight = 24
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 16
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("branchColumn"))
        col.width = 400
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.doubleAction = #selector(itemDoubleClicked(_:))
        
        // Setup Right-Click Menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Create branch from this branch...", action: #selector(contextCreateBranchClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Merge into current", action: #selector(contextMergeClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Rebase current onto this", action: #selector(contextRebaseClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Rename branch...", action: #selector(contextRenameClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete branch", action: #selector(contextDeleteClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Push branch to origin", action: #selector(contextPushClicked(_:)), keyEquivalent: ""))
        outlineView.menu = menu
        
        scroll.documentView = outlineView
        
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
    }
    
    // MARK: - Actions
    
    @objc private func itemDoubleClicked(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0 else { return }
        if let node = sender.item(atRow: row) as? BranchNode {
            presenter?.didDoubleClickNode(node)
        }
    }
    
    @objc private func contextCreateBranchClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didRequestCreateBranch(node)
        }
    }
    
    @objc private func contextMergeClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didClickMerge(node)
        }
    }

    @objc private func contextRebaseClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didClickRebase(node)
        }
    }
    
    @objc private func contextRenameClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didRequestRename(node)
        }
    }
    
    @objc private func contextDeleteClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didClickDelete(node)
        }
    }
    
    @objc private func contextPushClicked(_ sender: NSMenuItem) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        if let node = outlineView.item(atRow: row) as? BranchNode {
            presenter?.didClickPush(node)
        }
    }
    
    // MARK: - NSOutlineViewDataSource & Delegate
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return treeRoots.count
        }
        if let node = item as? BranchNode {
            return node.children.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? BranchNode {
            return !node.children.isEmpty
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return treeRoots[index]
        }
        let node = item as? BranchNode
        return node!.children[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? BranchNode else { return nil }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("BranchCell")
        var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        if let textField = cell?.textField {
            if node.isHeader {
                textField.stringValue = node.name
                textField.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                textField.textColor = NSColor.secondaryLabelColor
            } else {
                let displayName = node.name.replacingOccurrences(of: "remotes/", with: "")
                textField.stringValue = displayName
                
                if node.isCurrent {
                    textField.font = NSFont.systemFont(ofSize: 13, weight: .bold)
                    textField.textColor = NSColor.gitFlowAccent
                } else {
                    textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                    textField.textColor = NSColor.labelColor
                }
            }
        }
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let node = item as? BranchNode {
            return node.isHeader
        }
        return false
    }
    
    // MARK: - BranchesViewProtocol
    
    func showBranchTree(_ roots: [BranchNode]) {
        treeRoots = roots
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
