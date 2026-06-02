import Cocoa

protocol BlameViewProtocol: AnyObject {
    func showBlameLines(_ lines: [GitBlameLine])
    func showLoading(_ isLoading: Bool)
}

class BlameViewController: NSViewController, BlameViewProtocol, NSTableViewDataSource, NSTableViewDelegate {
    var presenter: BlamePresenterProtocol!
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    
    private var blameLines: [GitBlameLine] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        tableView.dataSource = self
        tableView.delegate = self
        
        presenter.viewDidLoad()
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
            
            cell?.wantsLayer = true
            cell?.layer?.backgroundColor = NSColor.clear.cgColor
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
