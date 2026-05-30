// MARK: - TagsViewController.swift

import Cocoa

protocol TagsViewProtocol: AnyObject {
    func showTags(_ tags: [GitTag])
    func showLoading(_ loading: Bool)
}

class TagsViewController: NSViewController, TagsViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    
    var presenter: TagsPresenterProtocol?
    
    private var tags: [GitTag] = []
    
    // UI Elements
    private var tableView: NSTableView!
    
    private var tagInputField: NSTextField!
    private var createTagButton: NSButton!
    
    private var pushRemoteInputField: NSTextField!
    private var pushTagButton: NSButton!
    private var deleteTagButton: NSButton!
    
    private var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Action Header (Create Tag)
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
        
        tagInputField = NSTextField()
        tagInputField.placeholderString = "Tag name (e.g. v1.0.0)..."
        tagInputField.font = NSFont.systemFont(ofSize: 12)
        tagInputField.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(tagInputField)
        
        createTagButton = NSButton(title: "Create Tag", target: self, action: #selector(createTagClicked(_:)))
        createTagButton.bezelStyle = .push
        createTagButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(createTagButton)
        
        // 2. Setup Tags Table
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        
        tableView = NSTableView()
        tableView.headerView = nil // Hide headers for simple tag lists
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.gridColor = NSColor.separatorColor
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.allowsMultipleSelection = false
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tagColumn"))
        col.width = 400
        tableView.addTableColumn(col)
        
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        
        // 3. Bottom Action Panel (Push & Delete)
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
        
        pushRemoteInputField = NSTextField()
        pushRemoteInputField.placeholderString = "Remote (default: origin)"
        pushRemoteInputField.font = NSFont.systemFont(ofSize: 12)
        pushRemoteInputField.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(pushRemoteInputField)
        
        pushTagButton = NSButton(title: "Push Tag to Remote", target: self, action: #selector(pushTagClicked(_:)))
        pushTagButton.bezelStyle = .push
        pushTagButton.isEnabled = false
        pushTagButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(pushTagButton)
        
        deleteTagButton = NSButton(title: "Delete Tag", target: self, action: #selector(deleteTagClicked(_:)))
        deleteTagButton.bezelStyle = .push
        deleteTagButton.isEnabled = false
        deleteTagButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(deleteTagButton)
        
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
            
            tagInputField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            tagInputField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            tagInputField.widthAnchor.constraint(equalToConstant: 300),
            
            createTagButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            createTagButton.leadingAnchor.constraint(equalTo: tagInputField.trailingAnchor, constant: 12),
            
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
            
            pushRemoteInputField.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            pushRemoteInputField.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 16),
            pushRemoteInputField.widthAnchor.constraint(equalToConstant: 160),
            
            pushTagButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            pushTagButton.leadingAnchor.constraint(equalTo: pushRemoteInputField.trailingAnchor, constant: 10),
            
            deleteTagButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            deleteTagButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -16),
            
            progressIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            progressIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func createTagClicked(_ sender: NSButton) {
        let name = tagInputField.stringValue
        presenter?.didClickCreateTag(name: name)
        tagInputField.stringValue = ""
    }
    
    @objc private func pushTagClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < tags.count else { return }
        let remote = pushRemoteInputField.stringValue
        presenter?.didClickPushTag(tags[row], remote: remote)
    }
    
    @objc private func deleteTagClicked(_ sender: NSButton) {
        let row = tableView.selectedRow
        guard row >= 0 && row < tags.count else { return }
        presenter?.didClickDeleteTag(tags[row])
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tags.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tag = tags[row]
        let cellId = NSUserInterfaceItemIdentifier("TagCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId
            
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -16),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        if let textField = cell?.textField {
            textField.stringValue = tag.name
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = NSColor.labelColor
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        pushTagButton.isEnabled = hasSelection
        deleteTagButton.isEnabled = hasSelection
    }
    
    // MARK: - TagsViewProtocol
    
    func showTags(_ tags: [GitTag]) {
        self.tags = tags
        tableView.reloadData()
        
        pushTagButton.isEnabled = false
        deleteTagButton.isEnabled = false
    }
    
    func showLoading(_ loading: Bool) {
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}
