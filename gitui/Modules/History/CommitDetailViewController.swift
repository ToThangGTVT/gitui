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
    private var hashPill: NSTextField!
    private var avatarView: AvatarView!
    private var authorLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var messageTextView: NSTextView!
    private var changedFilesTableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // 1. Hash Pill
        hashPill = NSTextField(labelWithString: "COMMIT HASH")
        hashPill.font = NSFont(name: "Menlo", size: 10) ?? NSFont.userFixedPitchFont(ofSize: 10)
        hashPill.textColor = NSColor.secondaryLabelColor
        hashPill.alignment = .center
        hashPill.wantsLayer = true
        hashPill.layer?.cornerRadius = 4
        hashPill.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        hashPill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hashPill)
        
        // 2. Avatar Circle View
        avatarView = AvatarView(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(avatarView)
        
        // 3. Author Name
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        authorLabel.textColor = NSColor.labelColor
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(authorLabel)
        
        // 4. Date Label
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.font = NSFont.systemFont(ofSize: 11)
        dateLabel.textColor = NSColor.secondaryLabelColor
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dateLabel)
        
        // 5. Message Text View
        let messageScroll = NSScrollView()
        messageScroll.hasVerticalScroller = true
        messageScroll.borderType = .noBorder
        messageScroll.drawsBackground = false
        messageScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageScroll)
        
        messageTextView = NSTextView()
        messageTextView.isRichText = false
        messageTextView.isEditable = false
        messageTextView.font = NSFont.systemFont(ofSize: 12)
        messageTextView.textColor = NSColor.labelColor
        messageTextView.backgroundColor = NSColor.clear
        messageScroll.documentView = messageTextView
        
        // 6. Changed Files Label
        let filesTitle = NSTextField(labelWithString: "CHANGED FILES")
        filesTitle.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        filesTitle.textColor = NSColor.secondaryLabelColor
        filesTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filesTitle)
        
        // 7. Changed Files Table
        let filesScroll = NSScrollView()
        filesScroll.hasVerticalScroller = true
        filesScroll.borderType = .lineBorder
        filesScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filesScroll)
        
        changedFilesTableView = NSTableView()
        changedFilesTableView.headerView = nil
        changedFilesTableView.backgroundColor = NSColor.controlBackgroundColor
        changedFilesTableView.gridColor = NSColor.separatorColor
        changedFilesTableView.gridStyleMask = .solidHorizontalGridLineMask
        changedFilesTableView.allowsMultipleSelection = false
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fileCol"))
        col.width = 250
        changedFilesTableView.addTableColumn(col)
        
        changedFilesTableView.dataSource = self
        changedFilesTableView.delegate = self
        filesScroll.documentView = changedFilesTableView
        
        // Constraints
        NSLayoutConstraint.activate([
            hashPill.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            hashPill.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hashPill.widthAnchor.constraint(equalToConstant: 95),
            hashPill.heightAnchor.constraint(equalToConstant: 18),
            
            avatarView.topAnchor.constraint(equalTo: hashPill.bottomAnchor, constant: 12),
            avatarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),
            
            authorLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 1),
            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            authorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            dateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            messageScroll.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 12),
            messageScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            messageScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            messageScroll.heightAnchor.constraint(equalToConstant: 80),
            
            filesTitle.topAnchor.constraint(equalTo: messageScroll.bottomAnchor, constant: 16),
            filesTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            filesScroll.topAnchor.constraint(equalTo: filesTitle.bottomAnchor, constant: 8),
            filesScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filesScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filesScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
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
        var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId
            
            let statusBadge = NSTextField(labelWithString: "")
            statusBadge.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            statusBadge.alignment = .center
            statusBadge.wantsLayer = true
            statusBadge.layer?.cornerRadius = 3
            statusBadge.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(statusBadge)
            
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 11)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            NSLayoutConstraint.activate([
                statusBadge.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                statusBadge.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                statusBadge.widthAnchor.constraint(equalToConstant: 18),
                statusBadge.heightAnchor.constraint(equalToConstant: 16),
                
                label.leadingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        if let textField = cell?.textField {
            textField.stringValue = file.path
        }
        
        if let badge = cell?.subviews.first(where: { $0 is NSTextField && $0 !== cell?.textField }) as? NSTextField {
            badge.stringValue = file.status
            if file.status == "A" || file.status == "M" {
                badge.textColor = NSColor.gitFlowStagedAddText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedAdd.cgColor
            } else if file.status == "D" {
                badge.textColor = NSColor.gitFlowStagedDeleteText
                badge.layer?.backgroundColor = NSColor.gitFlowStagedDelete.cgColor
            } else {
                badge.textColor = NSColor.gitFlowAccent
                badge.layer?.backgroundColor = NSColor.gitFlowAccent.withAlphaComponent(0.15).cgColor
            }
        }
        
        return cell
    }
}
