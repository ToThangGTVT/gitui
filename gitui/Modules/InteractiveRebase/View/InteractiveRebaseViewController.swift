import Cocoa

protocol InteractiveRebaseViewProtocol: AnyObject {
    func showItems(_ items: [RebaseTodoItem])
    func showLoading(_ isLoading: Bool)
}

class InteractiveRebaseViewController: NSViewController, InteractiveRebaseViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    var presenter: InteractiveRebasePresenterProtocol!
    
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var progressIndicator: NSProgressIndicator!
    private var items: [RebaseTodoItem] = []
    
    private let dragType = NSPasteboard.PasteboardType("com.gitui.rebase.row")
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }
    
    private func setupUI() {
        // Bottom buttons container
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        
        let startButton = NSButton(title: "Start Rebase", target: self, action: #selector(startClicked))
        startButton.bezelStyle = .rounded
        if #available(macOS 11.0, *) { startButton.bezelColor = NSColor.systemBlue; startButton.contentTintColor = .white }
        startButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(startButton)
        
        let abortButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        abortButton.bezelStyle = .rounded
        abortButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(abortButton)
        
        // Scroll & Table
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 32
        tableView.style = .inset
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        
        let actionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Action"))
        actionCol.title = "Action"
        actionCol.width = 100
        tableView.addTableColumn(actionCol)
        
        let hashCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Hash"))
        hashCol.title = "Commit"
        hashCol.width = 80
        tableView.addTableColumn(hashCol)
        
        let msgCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Message"))
        msgCol.title = "Message"
        msgCol.resizingMask = .autoresizingMask
        tableView.addTableColumn(msgCol)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerForDraggedTypes([dragType])
        
        scrollView.documentView = tableView
        
        // Progress
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 50),
            
            startButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            startButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            
            abortButton.trailingAnchor.constraint(equalTo: startButton.leadingAnchor, constant: -12),
            abortButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func startClicked() {
        presenter.startRebase()
    }
    
    @objc private func cancelClicked() {
        presenter.abortRebase()
    }
    
    @objc private func actionChanged(_ sender: NSPopUpButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, let title = sender.titleOfSelectedItem, let action = RebaseAction(rawValue: title.lowercased()) else { return }
        presenter.updateItemAction(at: row, action: action)
    }
    
    // MARK: - Protocol
    
    func showItems(_ items: [RebaseTodoItem]) {
        self.items = items
        tableView.reloadData()
    }
    
    func showLoading(_ isLoading: Bool) {
        if isLoading { progressIndicator.startAnimation(nil) } else { progressIndicator.stopAnimation(nil) }
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let id = tableColumn?.identifier.rawValue ?? ""
        
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = NSUserInterfaceItemIdentifier(id)
        }
        
        cell?.subviews.forEach { $0.removeFromSuperview() }
        
        if id == "Action" {
            let popup = NSPopUpButton(frame: NSRect(x: 4, y: 4, width: 90, height: 24), pullsDown: false)
            popup.addItems(withTitles: RebaseAction.allCases.map { $0.rawValue.capitalized })
            popup.selectItem(withTitle: item.action.rawValue.capitalized)
            popup.target = self
            popup.action = #selector(actionChanged(_:))
            cell?.addSubview(popup)
        } else {
            let text = NSTextField(labelWithString: id == "Hash" ? item.hash : item.message)
            text.font = id == "Hash" ? NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold) : NSFont.systemFont(ofSize: 13)
            text.lineBreakMode = .byTruncatingTail
            text.frame = NSRect(x: 4, y: 6, width: tableColumn!.width - 8, height: 20)
            text.autoresizingMask = [.width]
            cell?.addSubview(text)
        }
        return cell
    }
    
    // MARK: - Drag and Drop
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: dragType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above { return .move }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let sourceString = item.string(forType: dragType),
              let sourceRow = Int(sourceString) else { return false }
        
        var destRow = row
        if destRow > sourceRow { destRow -= 1 }
        
        if sourceRow != destRow {
            presenter.moveItem(from: sourceRow, to: destRow)
            // Animate
            tableView.moveRow(at: sourceRow, to: destRow)
        }
        return true
    }
}
