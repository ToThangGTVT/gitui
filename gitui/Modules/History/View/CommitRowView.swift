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
        
        // 2. Content Stack View (Vertical)
        let contentStackView = NSStackView()
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 2
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStackView)
        
        // 3. Message Label
        messageLabel = NSTextField(labelWithString: "")
        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(messageLabel)
        
        // 4. Badge Stack View
        badgeStackView = NSStackView()
        badgeStackView.orientation = .horizontal
        badgeStackView.spacing = 8
        badgeStackView.alignment = .centerY
        badgeStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(badgeStackView)
        
        // 5. Author Label
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 12)
        authorLabel.textColor = NSColor.secondaryLabelColor
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.alignment = .left
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(authorLabel)
        
        // 6. Date Label
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.font = NSFont.systemFont(ofSize: 12)
        dateLabel.textColor = NSColor.secondaryLabelColor
        dateLabel.alignment = .right
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dateLabel)
        
        // Set priority to prevent clipping
        authorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // 7. Constraints
        NSLayoutConstraint.activate([
            graphView.leadingAnchor.constraint(equalTo: leadingAnchor),
            graphView.topAnchor.constraint(equalTo: topAnchor),
            graphView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStackView.leadingAnchor.constraint(equalTo: graphView.trailingAnchor, constant: 8),
            contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            authorLabel.leadingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 12),
            authorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            authorLabel.widthAnchor.constraint(equalToConstant: 80),
            
            dateLabel.leadingAnchor.constraint(equalTo: authorLabel.trailingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    func configure(with commit: CommitNode, maxLaneCount: Int) {
        graphView.laneCount = maxLaneCount
        graphView.laneIndex = commit.laneIndex
        graphView.incomingEdges = commit.incomingEdges
        graphView.outgoingEdges = commit.outgoingEdges
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
        
        badgeStackView.isHidden = refs.isEmpty
        
        for ref in refs {
            let badgeView: BadgeView
            
            switch ref {
            case .localBranch(let name):
                badgeView = BadgeView(
                    text: name,
                    textColor: NSColor(red: 0.05, green: 0.27, blue: 0.49, alpha: 1.0),
                    bgColor: NSColor(red: 0.90, green: 0.94, blue: 0.98, alpha: 1.0)
                )
            case .remoteBranch(let name):
                badgeView = BadgeView(
                    text: name,
                    textColor: NSColor(red: 0.15, green: 0.31, blue: 0.04, alpha: 1.0),
                    bgColor: NSColor(red: 0.92, green: 0.95, blue: 0.87, alpha: 1.0)
                )
            case .tag(let name):
                badgeView = BadgeView(
                    text: "tag: " + name,
                    textColor: NSColor(red: 0.39, green: 0.22, blue: 0.02, alpha: 1.0),
                    bgColor: NSColor(red: 0.98, green: 0.93, blue: 0.85, alpha: 1.0)
                )
            case .head:
                badgeView = BadgeView(
                    text: "HEAD",
                    textColor: NSColor(red: 0.24, green: 0.20, blue: 0.54, alpha: 1.0),
                    bgColor: NSColor(red: 0.93, green: 0.93, blue: 0.99, alpha: 1.0),
                    isBold: true
                )
            }
            
            badgeStackView.addArrangedSubview(badgeView)
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

class BadgeView: NSView {
    private let label: NSTextField
    
    init(text: String, textColor: NSColor, bgColor: NSColor, isBold: Bool = false) {
        label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 10.5, weight: isBold ? .bold : .regular)
        label.textColor = textColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3.5
        self.layer?.backgroundColor = bgColor.cgColor
        
        addSubview(label)
        
        // Adjust padding constants to make it look perfectly centered
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
