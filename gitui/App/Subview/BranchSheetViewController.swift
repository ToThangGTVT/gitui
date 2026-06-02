// MARK: - BranchSheetViewController.swift

import Cocoa

class BranchSheetViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var checkoutButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var currentLabel: NSTextField!
    
    private let allBranches: [GitBranch]
    private var filteredBranches: [GitBranch]
    private let onSelect: (GitBranch) -> Void
    
    init(branches: [GitBranch], onSelect: @escaping (GitBranch) -> Void) {
        self.allBranches = branches
        self.filteredBranches = branches
        self.onSelect = onSelect
        super.init(nibName: "BranchSheetViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        
        // Config table double action
        tableView.doubleAction = #selector(doubleClickCheckout)
        tableView.target = self
        tableView.dataSource = self
        tableView.delegate = self
        
        searchField.delegate = self
        
        // Current branch info
        let currentBranch = allBranches.first(where: { $0.isCurrent })
        currentLabel.stringValue = "Current: \(currentBranch?.name ?? "unknown")"
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Pre-select current branch
        if let idx = filteredBranches.firstIndex(where: { $0.isCurrent }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
        view.window?.makeFirstResponder(searchField)
    }
    
    // MARK: - Actions
    
    private func closeSheet() {
        guard let sheetWindow = view.window, let parent = sheetWindow.sheetParent else { return }
        parent.endSheet(sheetWindow)
    }
    
    @IBAction func cancelClicked(_ sender: Any) {
        closeSheet()
    }
    
    @IBAction func checkoutClicked(_ sender: Any) {
        let row = tableView.selectedRow
        guard row >= 0 && row < filteredBranches.count else { return }
        let branch = filteredBranches[row]
        closeSheet()
        onSelect(branch)
    }
    
    @objc private func doubleClickCheckout() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredBranches.count else { return }
        let branch = filteredBranches[row]
        closeSheet()
        onSelect(branch)
    }
    
    // MARK: - NSSearchFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredBranches = allBranches
        } else {
            filteredBranches = allBranches.filter { $0.name.lowercased().contains(query) }
        }
        tableView.reloadData()
        checkoutButton.isEnabled = false
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredBranches.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        checkoutButton.isEnabled = row >= 0 && row < filteredBranches.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let branch = filteredBranches[row]
        let cellId = NSUserInterfaceItemIdentifier("BranchCell")
        guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView else { return nil }
        
        cell.textField?.stringValue = branch.name
        
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            cell.imageView?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        }
        
        if branch.isCurrent {
            cell.textField?.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            cell.textField?.textColor = NSColor.controlAccentColor
            cell.imageView?.contentTintColor = NSColor.controlAccentColor
            if let check = cell.subviews.first(where: { $0.identifier?.rawValue == "checkmark" }) as? NSTextField {
                check.stringValue = "✓"
                check.textColor = NSColor.controlAccentColor
            }
        } else {
            cell.textField?.font = NSFont.systemFont(ofSize: 14)
            cell.textField?.textColor = NSColor.labelColor
            cell.imageView?.contentTintColor = NSColor.secondaryLabelColor
            if let check = cell.subviews.first(where: { $0.identifier?.rawValue == "checkmark" }) as? NSTextField {
                check.stringValue = ""
            }
        }
        
        return cell
    }
}
