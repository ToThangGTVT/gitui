// MARK: - CommitDetailViewController.swift

import Cocoa

class AvatarView: NSView {
    var name: String = "" {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        
        // Generate consistent background color based on name hash
        let hash = abs(name.hashValue)
        let colors: [NSColor] = [
            NSColor(red: 0.22, green: 0.54, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.11, green: 0.62, blue: 0.46, alpha: 1.0),
            NSColor(red: 0.50, green: 0.47, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.85, green: 0.35, blue: 0.19, alpha: 1.0),
            NSColor(red: 0.83, green: 0.33, blue: 0.49, alpha: 1.0)
        ]
        let color = colors[hash % colors.count]
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds)
        
        // Extract initials
        let comps = name.components(separatedBy: " ")
        var initials = ""
        if let first = comps.first?.prefix(1) {
            initials += first
        }
        if comps.count > 1, let last = comps.last?.prefix(1) {
            initials += last
        }
        initials = initials.uppercased()
        
        // Draw text centered
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: radius * 0.9, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let size = initials.size(withAttributes: attributes)
        let textRect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        initials.draw(in: textRect, withAttributes: attributes)
    }
}

class CommitDetailViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    private var changedFiles: [GitFileStatus] = []
    
    // UI Elements
    @IBOutlet private weak var hashPill: NSTextField!
    @IBOutlet private weak var avatarView: AvatarView!
    @IBOutlet private weak var authorLabel: NSTextField!
    @IBOutlet private weak var dateLabel: NSTextField!
    @IBOutlet private weak var messageTextView: NSTextView!
    @IBOutlet private weak var changedFilesTableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 1. Hash Pill Style
        hashPill.stringValue = "COMMIT HASH"
        hashPill.font = NSFont(name: "Menlo", size: 10) ?? NSFont.userFixedPitchFont(ofSize: 10)
        hashPill.textColor = NSColor.secondaryLabelColor
        hashPill.alignment = .center
        hashPill.wantsLayer = true
        hashPill.layer?.cornerRadius = 4
        hashPill.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 2. Author Name Style
        authorLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        authorLabel.textColor = NSColor.labelColor
        
        // 3. Date Label Style
        dateLabel.font = NSFont.systemFont(ofSize: 11)
        dateLabel.textColor = NSColor.secondaryLabelColor
        
        // 4. Message Text View Style
        messageTextView.isRichText = false
        messageTextView.isEditable = false
        messageTextView.font = NSFont.systemFont(ofSize: 12)
        messageTextView.textColor = NSColor.labelColor
        messageTextView.backgroundColor = NSColor.clear
        
        // 5. Changed Files Table Setup
        changedFilesTableView.headerView = nil
        changedFilesTableView.backgroundColor = NSColor.controlBackgroundColor
        changedFilesTableView.gridColor = NSColor.separatorColor
        changedFilesTableView.gridStyleMask = .solidHorizontalGridLineMask
        changedFilesTableView.allowsMultipleSelection = false
        
        let nib = NSNib(nibNamed: "FileDetailCell", bundle: nil)
        changedFilesTableView.register(nib, forIdentifier: NSUserInterfaceItemIdentifier("fileDetailCell"))
        
        changedFilesTableView.dataSource = self
        changedFilesTableView.delegate = self
    }
    
    func configure(with commit: CommitNode) {
        hashPill.stringValue = " " + commit.shortHash.uppercased() + " "
        avatarView.name = commit.author
        authorLabel.stringValue = commit.author
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.stringValue = formatter.string(from: commit.date)
        
        messageTextView.string = commit.message
        
        // Fetch files changed in background
        loadFilesChanged(for: commit.hash)
    }
    
    private func loadFilesChanged(for commitHash: String) {
        guard let path = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        
        Task {
            do {
                // Command: show --name-status --pretty="" hash
                let filesOutput = try await GitService.shared.runGit(["show", "--name-status", "--pretty=format:", commitHash], in: path)
                var files: [GitFileStatus] = []
                
                let lines = filesOutput.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    
                    let comps = trimmed.components(separatedBy: .whitespaces)
                    let cleanComps = comps.filter { !$0.isEmpty }
                    
                    if cleanComps.count >= 2 {
                        let status = cleanComps[0]
                        let filePath = cleanComps[1]
                        files.append(GitFileStatus(path: filePath, status: status, isStaged: false))
                    }
                }
                
                await MainActor.run {
                    self.changedFiles = files
                    self.changedFilesTableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.changedFiles = []
                    self.changedFilesTableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return changedFiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = changedFiles[row]
        let cellId = NSUserInterfaceItemIdentifier("fileDetailCell")
        guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? FileDetailCell else {
            return nil
        }
        
        cell.textField?.stringValue = file.path
        cell.statusBadge.stringValue = file.status
        
        cell.statusBadge.wantsLayer = true
        cell.statusBadge.layer?.cornerRadius = 3
        
        if file.status == "A" || file.status == "M" {
            cell.statusBadge.textColor = NSColor.gitFlowStagedAddText
            cell.statusBadge.layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor
        } else if file.status == "D" {
            cell.statusBadge.textColor = NSColor.gitFlowStagedDeleteText
            cell.statusBadge.layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor
        } else {
            cell.statusBadge.textColor = NSColor.gitFlowAccent
            cell.statusBadge.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
        }
        
        return cell
    }
}
