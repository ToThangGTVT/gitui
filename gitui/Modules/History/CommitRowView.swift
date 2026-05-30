// MARK: - CommitRowView.swift

import Cocoa

class CommitRowView: NSTableCellView {
    
    // UI Elements
    private var graphView: CommitGraphView!
    private var messageLabel: NSTextField!
    private var badgeStackView: NSStackView!
    private var authorLabel: NSTextField!
    private var dateLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // 1. Graph View (drawn on left side)
        graphView = CommitGraphView()
        graphView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(graphView)
        
        // Ensure the graph view doesn't stretch or compress and respects its intrinsicContentSize
        graphView.setContentHuggingPriority(.required, for: .horizontal)
        graphView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // 2. Message Label
        messageLabel = NSTextField(labelWithString: "")
        messageLabel.font = NSFont.systemFont(ofSize: 12)
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
        
        // 3. Badge Stack View
        badgeStackView = NSStackView()
        badgeStackView.orientation = .horizontal
        badgeStackView.spacing = 4
        badgeStackView.alignment = .centerY
        badgeStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeStackView)
        
        // 4. Author Label
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 11)
        authorLabel.textColor = NSColor.secondaryLabelColor
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.alignment = .left
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(authorLabel)
        
        // 5. Date Label
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.font = NSFont.systemFont(ofSize: 11)
        dateLabel.textColor = NSColor.secondaryLabelColor
        dateLabel.alignment = .right
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dateLabel)
        
        // Set priority to prevent clipping
        authorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // 6. Constraints
        NSLayoutConstraint.activate([
            graphView.leadingAnchor.constraint(equalTo: leadingAnchor),
            graphView.topAnchor.constraint(equalTo: topAnchor),
            graphView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            messageLabel.leadingAnchor.constraint(equalTo: graphView.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            badgeStackView.leadingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: 8),
            badgeStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            authorLabel.leadingAnchor.constraint(equalTo: badgeStackView.trailingAnchor, constant: 12),
            authorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            authorLabel.widthAnchor.constraint(equalToConstant: 80),
            
            dateLabel.leadingAnchor.constraint(equalTo: authorLabel.trailingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    func configure(with commit: CommitNode, maxLaneCount: Int, hasIncomingLine: Bool) {
        graphView.laneCount = maxLaneCount
        graphView.laneIndex = commit.laneIndex
        graphView.edges = commit.edges
        graphView.hasIncomingLine = hasIncomingLine
        graphView.needsDisplay = true
        
        messageLabel.stringValue = commit.message
        authorLabel.stringValue = commit.author
        dateLabel.stringValue = formatRelativeDate(commit.date)
        
        // Configure badges
        configureBadges(for: commit.refs)
    }
    
    private func configureBadges(for refs: [GitRef]) {
        // Clear old badges
        for view in badgeStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        for ref in refs {
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 9.5)
            label.alignment = .center
            label.wantsLayer = true
            label.layer?.cornerRadius = 3.5
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // Set margins
            label.heightAnchor.constraint(equalToConstant: 14).isActive = true
            
            switch ref {
            case .localBranch(let name):
                label.stringValue = " " + name + " "
                label.textColor = NSColor(red: 0.05, green: 0.27, blue: 0.49, alpha: 1.0) // #0C447C
                label.layer?.backgroundColor = NSColor(red: 0.90, green: 0.94, blue: 0.98, alpha: 1.0).cgColor // #E6F1FB
            case .remoteBranch(let name):
                label.stringValue = " " + name + " "
                label.textColor = NSColor(red: 0.15, green: 0.31, blue: 0.04, alpha: 1.0) // #27500A
                label.layer?.backgroundColor = NSColor(red: 0.92, green: 0.95, blue: 0.87, alpha: 1.0).cgColor // #EAF3DE
            case .tag(let name):
                label.stringValue = " tag: " + name + " "
                label.textColor = NSColor(red: 0.39, green: 0.22, blue: 0.02, alpha: 1.0) // #633806
                label.layer?.backgroundColor = NSColor(red: 0.98, green: 0.93, blue: 0.85, alpha: 1.0).cgColor // #FAEEDA
            case .head:
                label.stringValue = " HEAD "
                label.font = NSFont.systemFont(ofSize: 9.5, weight: .bold)
                label.textColor = NSColor(red: 0.24, green: 0.20, blue: 0.54, alpha: 1.0) // #3C3489
                label.layer?.backgroundColor = NSColor(red: 0.93, green: 0.93, blue: 0.99, alpha: 1.0).cgColor // #EEEDFE
            }
            
            badgeStackView.addArrangedSubview(label)
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 { return "1d ago" }
            if day < 7 { return "\(day)d ago" }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return dateFormatter.string(from: date)
        }
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        }
        
        return "now"
    }
}
