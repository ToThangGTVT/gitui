import Cocoa

protocol BlameViewProtocol: AnyObject {
    func showBlameLines(_ lines: [GitBlameLine])
    func showLoading(_ isLoading: Bool)
}

class BlameViewController: NSViewController, BlameViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    var presenter: BlamePresenterProtocol!
    
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var progressIndicator: NSProgressIndicator!
    
    private var blameLines: [GitBlameLine] = []
    
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
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView = NSTableView()
        tableView.headerView = nil // No header needed, just side by side
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.gridColor = NSColor.gridColor.withAlphaComponent(0.2)
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = NSColor.textBackgroundColor
        tableView.allowsMultipleSelection = false
        
        // Info Column
        let infoCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("InfoColumn"))
        infoCol.width = 250
        infoCol.minWidth = 200
        infoCol.maxWidth = 350
        tableView.addTableColumn(infoCol)
        
        // Code Column
        let codeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CodeColumn"))
        codeCol.resizingMask = .autoresizingMask
        tableView.addTableColumn(codeCol)
        
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func showBlameLines(_ lines: [GitBlameLine]) {
        self.blameLines = lines
        tableView.reloadData()
    }
    
    func showLoading(_ isLoading: Bool) {
        if isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
    
    // MARK: - NSTableViewDataSource / Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return blameLines.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let line = blameLines[row]
        let isInfoCol = tableColumn?.identifier.rawValue == "InfoColumn"
        
        let cellId = NSUserInterfaceItemIdentifier(isInfoCol ? "InfoCell" : "CodeCell")
        var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId
            
            let textField = NSTextField(labelWithString: "")
            textField.isEditable = false
            textField.isSelectable = isInfoCol ? false : true
            textField.drawsBackground = false
            textField.isBordered = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = isInfoCol ? .byTruncatingTail : .byClipping
            
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: isInfoCol ? 8 : 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        if isInfoCol {
            cell?.textField?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            cell?.textField?.textColor = .secondaryLabelColor
            let shortHash = line.commitHash.prefix(8)
            let author = line.author.prefix(12).padding(toLength: 12, withPad: " ", startingAt: 0)
            cell?.textField?.stringValue = "\(shortHash)  \(author)  \(line.date)"
            
            // Highlight background slightly for info column
            cell?.wantsLayer = true
            cell?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        } else {
            cell?.textField?.font = NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            cell?.textField?.textColor = .labelColor
            cell?.textField?.stringValue = line.content
            
            cell?.wantsLayer = true
            cell?.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        return cell
    }
}
