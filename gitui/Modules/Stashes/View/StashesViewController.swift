// MARK: - StashesViewController.swift

import Cocoa

protocol StashesViewProtocol: AnyObject {
    func showStashes(_ stashes: [GitStash])
    func showLoading(_ loading: Bool)
}

class StashesViewController: NSViewController, StashesViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    
    var presenter: StashesPresenterProtocol?
    
    private var stashes: [GitStash] = []
    
    // UI Elements
    private var tableView: NSTableView!
    private var stashInputField: NSTextField!
    private var stashButton: NSButton!
    
    private var applyButton: NSButton!
    private var popButton: NSButton!
    private var dropButton: NSButton!
    private var clearButton: NSButton!
    
    private var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Setup Stash Action Header
        let headerView = NSView()
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(border)
        
        stashInputField = NSTextField()
        stashInputField.placeholderString = "Stash message (optional)..."
        stashInputField.font = NSFont.systemFont(ofSize: 12)
        stashInputField.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(stashInputField)
        
        stashButton = NSButton(title: "Stash Changes", target: self, action: #selector(stashClicked(_:)))
        stashButton.bezelStyle = .push
        stashButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(stashButton)
        
        // 2. Setup Stash Table View
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        
        tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.gridColor = NSColor.separatorColor
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.allowsMultipleSelection = false
        
        let colId = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("colId"))
        colId.title = "Stash"
        colId.width = 120
        tableView.addTableColumn(colId)
        
        let colMsg = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("colMsg"))
        colMsg.title = "Message"
        colMsg.width = 400
        tableView.addTableColumn(colMsg)
        
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        
        // 3. Setup Bottom Control Panel
        let bottomView = NSView()
        bottomView.wantsLayer = true
        bottomView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)
        
        let bottomBorder = NSView()
        bottomBorder.wantsLayer = true
        bottomBorder.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(bottomBorder)
        
        applyButton = NSButton(title: "Apply Stash", target: self, action: #selector(applyClicked(_:)))
        applyButton.bezelStyle = .push
        applyButton.isEnabled = false
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(applyButton)
        
        popButton = NSButton(title: "Pop Stash (Apply & Delete)", target: self, action: #selector(popClicked(_:)))
        popButton.bezelStyle = .push
        popButton.isEnabled = false
        popButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(popButton)
        
        dropButton = NSButton(title: "Discard Stash", target: self, action: #selector(dropClicked(_:)))
        dropButton.bezelStyle = .push
        dropButton.isEnabled = false
        dropButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(dropButton)
        
        clearButton = NSButton(title: "Clear All Stashes", target: self, action: #selector(clearClicked(_:)))
        clearButton.bezelStyle = .push
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(clearButton)
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            border.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            stashInputField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            stashInputField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            stashInputField.widthAnchor.constraint(equalToConstant: 300),
            
            stashButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            stashButton.leadingAnchor.constraint(equalTo: stashInputField.trailingAnchor, constant: 12),
            
            scroll.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 50),
            
            bottomBorder.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor),
            bottomBorder.topAnchor.constraint(equalTo: bottomView.topAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),
            
            applyButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            applyButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 16),
            
            popButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            popButton.leadingAnchor.constraint(equalTo: applyButton.trailingAnchor, constant: 12),
            
            dropButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            dropButton.leadingAnchor.constraint(equalTo: popButton.trailingAnchor, constant: 12),
            
            clearButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -16),
            
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func stashClicked(_ sender: NSButton) {
        let msg = stashInputField.stringValue
        presenter?.didClickSaveStash(message: msg)
        stashInputField.stringValue = ""
    }
    
    @objc private func applyClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < stashes.count else { return }
        presenter?.didClickApplyStash(stashes[row])
    }
    
    @objc private func popClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < stashes.count else { return }
        presenter?.didClickPopStash(stashes[row])
    }
    
    @objc private func dropClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < stashes.count else { return }
        presenter?.didClickDropStash(stashes[row])
    }
    
    @objc private func clearClicked(_ sender: NSButton) {
        presenter?.didClickClearStashes()
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return stashes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let stash = stashes[row]
        guard let colId = tableColumn?.identifier else { return nil }
        
        let cellId = NSUserInterfaceItemIdentifier("StashCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId
            
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
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = NSColor.labelColor
            if colId.rawValue == "colId" {
                textField.stringValue = stash.name
                textField.font = NSFont(name: "Menlo", size: 11)
            } else {
                textField.stringValue = stash.message
            }
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        applyButton.isEnabled = hasSelection
        popButton.isEnabled = hasSelection
        dropButton.isEnabled = hasSelection
    }
    
    // MARK: - StashesViewProtocol
    
    func showStashes(_ stashes: [GitStash]) {
        self.stashes = stashes
        tableView.reloadData()
        
        applyButton.isEnabled = false
        popButton.isEnabled = false
        dropButton.isEnabled = false
        clearButton.isEnabled = !stashes.isEmpty
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
