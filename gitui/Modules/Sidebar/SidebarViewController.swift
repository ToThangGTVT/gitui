// MARK: - SidebarViewController.swift

import Cocoa

protocol SidebarViewProtocol: AnyObject {
    func showBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?)
    func showLoading(_ loading: Bool)
}

class SidebarViewController: NSViewController, SidebarViewProtocol, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    var presenter: SidebarPresenterProtocol?
    
    private var bookmarks: [RepositoryBookmark] = []
    private var activePath: String?
    
    // UI Elements
    private var searchField: NSSearchField!
    private var tableView: NSTableView!
    private var actionButton: NSButton!
    private var removeButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    private let dragType = NSPasteboard.PasteboardType("gitflow.sidebar.drag")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.gitFlowSidebarBackground.cgColor
        
        // 1. Search Bar at Top
        let searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)
        
        searchField = NSSearchField()
        searchField.placeholderString = "Search repositories..."
        searchField.delegate = self
        searchField.font = NSFont.systemFont(ofSize: 11)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)
        
        // 2. Table Scroll View
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = NSColor.clear
        tableView.gridStyleMask = []
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 36
        tableView.doubleAction = #selector(tableDoubleClicked(_:))
        
        // Register drag & drop
        tableView.registerForDraggedTypes([dragType])
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bookmarkColumn"))
        col.width = 200
        tableView.addTableColumn(col)
        
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        
        // 3. Bottom Bar
        let bottomView = NSView()
        bottomView.wantsLayer = true
        bottomView.layer?.backgroundColor = NSColor.gitFlowSidebarBackground.cgColor
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)
        
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
        view.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),
            
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            
            scroll.topAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
        menu.addItem(NSMenuItem(title: "Clone Repository...", action: #selector(menuCloneClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Existing Repository...", action: #selector(menuOpenClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Initialize New Repository...", action: #selector(menuInitClicked(_:)), keyEquivalent: ""))
        
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
        let row = tableView.selectedRow
        guard row >= 0 && row < bookmarks.count else { return }
        presenter?.didClickRemoveRepository(at: row)
    }
    
    @objc private func tableDoubleClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0 && row < bookmarks.count else { return }
        presenter?.didSelectRepository(bookmarks[row])
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return bookmarks.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let bookmark = bookmarks[row]
        let isActive = bookmark.path == activePath
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("BookmarkCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let icon = NSImageView()
            icon.image = NSImage(named: NSImage.folderName)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(icon)
            
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            let pathLabel = NSTextField(labelWithString: "")
            pathLabel.font = NSFont.systemFont(ofSize: 9)
            pathLabel.textColor = NSColor.secondaryLabelColor
            pathLabel.lineBreakMode = .byTruncatingHead
            pathLabel.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(pathLabel)
            
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                icon.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16),
                
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                label.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 3),
                
                pathLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                pathLabel.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                pathLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 1)
            ])
        }
        
        if let textField = cell?.textField {
            textField.stringValue = bookmark.name
            if isActive {
                textField.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                textField.textColor = NSColor.gitFlowAccent
            } else {
                textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                textField.textColor = NSColor.labelColor
            }
        }
        
        if let pathLabel = cell?.subviews.first(where: { ($0 as? NSTextField)?.font?.pointSize == 9 }) as? NSTextField {
            pathLabel.stringValue = bookmark.path
            pathLabel.textColor = isActive ? NSColor.gitFlowAccent.withAlphaComponent(0.7) : NSColor.secondaryLabelColor
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton.isEnabled = tableView.selectedRow >= 0
    }
    
    // MARK: - Drag & Drop Reordering
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: dragType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let strValue = item.string(forType: dragType),
              let sourceRow = Int(strValue) else { return false }
        
        presenter?.didMoveRepository(from: sourceRow, to: row)
        return true
    }
    
    // MARK: - NSSearchFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        presenter?.filterBookmarks(query: field.stringValue)
    }
    
    // MARK: - SidebarViewProtocol
    
    func showBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?) {
        self.bookmarks = bookmarks
        self.activePath = activePath
        tableView.reloadData()
        removeButton.isEnabled = false
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
