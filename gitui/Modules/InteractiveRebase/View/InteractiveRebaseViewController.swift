import Cocoa

protocol InteractiveRebaseViewProtocol: AnyObject {
    func showItems(_ items: [RebaseTodoItem])
    func showLoading(_ isLoading: Bool)
}

class InteractiveRebaseViewController: NSViewController, InteractiveRebaseViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    var presenter: InteractiveRebasePresenterProtocol!
    
    @IBOutlet private weak var scrollView: NSScrollView!
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var startButton: NSButton!
    @IBOutlet private weak var abortButton: NSButton!
    private var items: [RebaseTodoItem] = []
    
    private let dragType = NSPasteboard.PasteboardType("com.gitui.rebase.row")
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: "InteractiveRebaseViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }
    
    private func setupUI() {
        if #available(macOS 11.0, *) {
            startButton.bezelColor = NSColor.systemBlue
            startButton.contentTintColor = .white
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerForDraggedTypes([dragType])
    }
    
    // MARK: - Actions
    
    @IBAction private func startClicked(_ sender: Any) {
        presenter.startRebase()
    }
    
    @IBAction private func cancelClicked(_ sender: Any) {
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
