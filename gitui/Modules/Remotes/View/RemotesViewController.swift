// MARK: - RemotesViewController.swift

import Cocoa

protocol RemotesViewProtocol: AnyObject {
    func showRemotes(_ remotes: [GitRemote])
    func showLoading(_ loading: Bool)
}

class RemotesViewController: NSViewController, RemotesViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    
    var presenter: RemotesPresenterProtocol?
    
    private var remotes: [GitRemote] = []
    
    // UI Elements
    private var tableView: NSTableView!
    
    private var nameInputField: NSTextField!
    private var urlInputField: NSTextField!
    private var addRemoteButton: NSButton!
    
    private var fetchButton: NSButton!
    private var branchInputField: NSTextField!
    private var pullButton: NSButton!
    private var pushButton: NSButton!
    private var removeButton: NSButton!
    
    private var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Action Header (Add Remote)
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
        
        nameInputField = NSTextField()
        nameInputField.placeholderString = "Remote name (e.g. origin)"
        nameInputField.font = NSFont.systemFont(ofSize: 12)
        nameInputField.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(nameInputField)
        
        urlInputField = NSTextField()
        urlInputField.placeholderString = "Git Repository URL..."
        urlInputField.font = NSFont.systemFont(ofSize: 12)
        urlInputField.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(urlInputField)
        
        addRemoteButton = NSButton(title: "Add Remote", target: self, action: #selector(addRemoteClicked(_:)))
        addRemoteButton.bezelStyle = .push
        addRemoteButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(addRemoteButton)
        
        // 2. Setup Remotes Table
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
        
        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("colName"))
        colName.title = "Remote Name"
        colName.width = 120
        tableView.addTableColumn(colName)
        
        let colUrl = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("colUrl"))
        colUrl.title = "URL"
        colUrl.width = 400
        tableView.addTableColumn(colUrl)
        
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        
        // 3. Setup Bottom Panel (Fetch / Pull / Push / Remove)
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
        
        fetchButton = NSButton(title: "Fetch Remote", target: self, action: #selector(fetchClicked(_:)))
        fetchButton.bezelStyle = .push
        fetchButton.isEnabled = false
        fetchButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(fetchButton)
        
        branchInputField = NSTextField()
        branchInputField.placeholderString = "Branch name (e.g. main)"
        branchInputField.font = NSFont.systemFont(ofSize: 12)
        branchInputField.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(branchInputField)
        
        pullButton = NSButton(title: "Pull", target: self, action: #selector(pullClicked(_:)))
        pullButton.bezelStyle = .push
        pullButton.isEnabled = false
        pullButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(pullButton)
        
        pushButton = NSButton(title: "Push", target: self, action: #selector(pushClicked(_:)))
        pushButton.bezelStyle = .push
        pushButton.isEnabled = false
        pushButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(pushButton)
        
        removeButton = NSButton(title: "Remove Remote", target: self, action: #selector(removeClicked(_:)))
        removeButton.bezelStyle = .push
        removeButton.isEnabled = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(removeButton)
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            border.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            nameInputField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            nameInputField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            nameInputField.widthAnchor.constraint(equalToConstant: 150),
            
            urlInputField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            urlInputField.leadingAnchor.constraint(equalTo: nameInputField.trailingAnchor, constant: 12),
            urlInputField.widthAnchor.constraint(equalToConstant: 350),
            
            addRemoteButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            addRemoteButton.leadingAnchor.constraint(equalTo: urlInputField.trailingAnchor, constant: 12),
            
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
            
            fetchButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            fetchButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 16),
            
            branchInputField.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            branchInputField.leadingAnchor.constraint(equalTo: fetchButton.trailingAnchor, constant: 16),
            branchInputField.widthAnchor.constraint(equalToConstant: 150),
            
            pullButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            pullButton.leadingAnchor.constraint(equalTo: branchInputField.trailingAnchor, constant: 10),
            
            pushButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            pushButton.leadingAnchor.constraint(equalTo: pullButton.trailingAnchor, constant: 8),
            
            removeButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -16),
            
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func addRemoteClicked(_ sender: NSButton) {
        let name = nameInputField.stringValue
        let url = urlInputField.stringValue
        presenter?.didClickAddRemote(name: name, url: url)
        
        nameInputField.stringValue = ""
        urlInputField.stringValue = ""
    }
    
    @objc private func fetchClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < remotes.count else { return }
        presenter?.didClickFetch(remotes[row])
    }
    
    @objc private func pullClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < remotes.count else { return }
        let branch = branchInputField.stringValue
        presenter?.didClickPull(remotes[row], branch: branch)
    }
    
    @objc private func pushClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < remotes.count else { return }
        let branch = branchInputField.stringValue
        presenter?.didClickPush(remotes[row], branch: branch)
    }
    
    @objc private func removeClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < remotes.count else { return }
        presenter?.didClickRemoveRemote(remotes[row])
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return remotes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let remote = remotes[row]
        guard let colId = tableColumn?.identifier else { return nil }
        
        let cellId = NSUserInterfaceItemIdentifier("RemoteCell")
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
            if colId.rawValue == "colName" {
                textField.stringValue = remote.name
                textField.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            } else {
                textField.stringValue = remote.url
            }
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        fetchButton.isEnabled = hasSelection
        pullButton.isEnabled = hasSelection
        pushButton.isEnabled = hasSelection
        removeButton.isEnabled = hasSelection
    }
    
    // MARK: - RemotesViewProtocol
    
    func showRemotes(_ remotes: [GitRemote]) {
        self.remotes = remotes
        tableView.reloadData()
        
        fetchButton.isEnabled = false
        pullButton.isEnabled = false
        pushButton.isEnabled = false
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
