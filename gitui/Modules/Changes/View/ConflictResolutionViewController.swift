// MARK: - ConflictResolutionViewController.swift

import Cocoa

protocol ConflictResolutionDelegate: AnyObject {
    func didResolveConflict(in filePath: String)
}

class ConflictResolutionViewController: NSViewController {
    
    private let filePath: String
    private let repoPath: String
    private var chunks: [ConflictChunk] = []
    
    weak var delegate: ConflictResolutionDelegate?
    
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var resolveContainer: NSView!
    
    init(filePath: String, repoPath: String) {
        self.filePath = filePath
        self.repoPath = repoPath
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupUI()
        loadFile()
    }
    
    private func setupUI() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        
        resolveContainer = NSView()
        resolveContainer.wantsLayer = true
        resolveContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        resolveContainer.translatesAutoresizingMaskIntoConstraints = false
        resolveContainer.isHidden = true
        view.addSubview(resolveContainer)
        
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.separatorColor.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        resolveContainer.addSubview(border)
        
        let resolveBtn = NSButton(title: "Mark as Resolved", target: self, action: #selector(markAsResolvedClicked))
        resolveBtn.bezelStyle = .texturedRounded
        resolveBtn.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        resolveBtn.translatesAutoresizingMaskIntoConstraints = false
        resolveContainer.addSubview(resolveBtn)
        
        scrollView.documentView = documentView
        
        NSLayoutConstraint.activate([
            resolveContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resolveContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resolveContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            resolveContainer.heightAnchor.constraint(equalToConstant: 50),
            
            border.leadingAnchor.constraint(equalTo: resolveContainer.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: resolveContainer.trailingAnchor),
            border.topAnchor.constraint(equalTo: resolveContainer.topAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            resolveBtn.centerYAnchor.constraint(equalTo: resolveContainer.centerYAnchor),
            resolveBtn.trailingAnchor.constraint(equalTo: resolveContainer.trailingAnchor, constant: -16),
            
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: resolveContainer.topAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor)
        ])
    }
    
    private func loadFile() {
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { return }
        
        chunks = ConflictParser.parse(content: content)
        renderChunks()
    }
    
    private func renderChunks() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        var hasConflicts = false
        
        for (index, chunk) in chunks.enumerated() {
            switch chunk {
            case .text(let content):
                let textView = createTextView(text: content, bgColor: .clear)
                stackView.addArrangedSubview(textView)
                textView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            case .conflict(let current, let incoming, let currentLbl, let incomingLbl):
                hasConflicts = true
                let conflictView = createConflictView(index: index, current: current, incoming: incoming, currentLbl: currentLbl, incomingLbl: incomingLbl)
                stackView.addArrangedSubview(conflictView)
                conflictView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            }
        }
        
        resolveContainer.isHidden = hasConflicts
    }
    
    private func createTextView(text: String, bgColor: NSColor) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = bgColor.cgColor
        
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont(name: "SF Mono", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createConflictView(index: Int, current: String, incoming: String, currentLbl: String, incomingLbl: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let vStack = NSStackView()
        vStack.orientation = .vertical
        vStack.spacing = 0
        vStack.alignment = .leading
        vStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vStack)
        
        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vStack.topAnchor.constraint(equalTo: container.topAnchor),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Current Section
        let curHeader = createHeader(title: "Current Change (\(currentLbl))", color: NSColor.systemGreen.withAlphaComponent(0.3))
        let curText = createTextView(text: current, bgColor: NSColor.systemGreen.withAlphaComponent(0.1))
        
        // Incoming Section
        let incHeader = createHeader(title: "Incoming Change (\(incomingLbl))", color: NSColor.systemBlue.withAlphaComponent(0.3))
        let incText = createTextView(text: incoming, bgColor: NSColor.systemBlue.withAlphaComponent(0.1))
        
        // Action Bar
        let actionBar = NSView()
        actionBar.wantsLayer = true
        actionBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        
        let acceptCurBtn = NSButton(title: "Accept Current", target: self, action: #selector(acceptCurrentClicked(_:)))
        acceptCurBtn.tag = index
        acceptCurBtn.bezelStyle = .rounded
        
        let acceptIncBtn = NSButton(title: "Accept Incoming", target: self, action: #selector(acceptIncomingClicked(_:)))
        acceptIncBtn.tag = index
        acceptIncBtn.bezelStyle = .rounded
        
        let acceptBothBtn = NSButton(title: "Accept Both", target: self, action: #selector(acceptBothClicked(_:)))
        acceptBothBtn.tag = index
        acceptBothBtn.bezelStyle = .rounded
        
        acceptCurBtn.translatesAutoresizingMaskIntoConstraints = false
        acceptIncBtn.translatesAutoresizingMaskIntoConstraints = false
        acceptBothBtn.translatesAutoresizingMaskIntoConstraints = false
        
        actionBar.addSubview(acceptCurBtn)
        actionBar.addSubview(acceptIncBtn)
        actionBar.addSubview(acceptBothBtn)
        
        NSLayoutConstraint.activate([
            actionBar.heightAnchor.constraint(equalToConstant: 36),
            acceptCurBtn.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            acceptCurBtn.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 8),
            
            acceptIncBtn.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            acceptIncBtn.leadingAnchor.constraint(equalTo: acceptCurBtn.trailingAnchor, constant: 8),
            
            acceptBothBtn.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            acceptBothBtn.leadingAnchor.constraint(equalTo: acceptIncBtn.trailingAnchor, constant: 8)
        ])
        
        vStack.addArrangedSubview(curHeader)
        vStack.addArrangedSubview(curText)
        vStack.addArrangedSubview(incHeader)
        vStack.addArrangedSubview(incText)
        vStack.addArrangedSubview(actionBar)
        
        curHeader.widthAnchor.constraint(equalTo: vStack.widthAnchor).isActive = true
        curText.widthAnchor.constraint(equalTo: vStack.widthAnchor).isActive = true
        incHeader.widthAnchor.constraint(equalTo: vStack.widthAnchor).isActive = true
        incText.widthAnchor.constraint(equalTo: vStack.widthAnchor).isActive = true
        actionBar.widthAnchor.constraint(equalTo: vStack.widthAnchor).isActive = true
        
        return container
    }
    
    private func createHeader(title: String, color: NSColor) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])
        return view
    }
    
    @objc private func acceptCurrentClicked(_ sender: NSButton) {
        let index = sender.tag
        guard case let .conflict(current, _, _, _) = chunks[index] else { return }
        resolveConflict(at: index, with: current)
    }
    
    @objc private func acceptIncomingClicked(_ sender: NSButton) {
        let index = sender.tag
        guard case let .conflict(_, incoming, _, _) = chunks[index] else { return }
        resolveConflict(at: index, with: incoming)
    }
    
    @objc private func acceptBothClicked(_ sender: NSButton) {
        let index = sender.tag
        guard case let .conflict(current, incoming, _, _) = chunks[index] else { return }
        let combined = [current, incoming].filter { !$0.isEmpty }.joined(separator: "\n")
        resolveConflict(at: index, with: combined)
    }
    
    private func resolveConflict(at index: Int, with text: String) {
        chunks[index] = .text(content: text)
        saveFile()
        renderChunks()
    }
    
    private func saveFile() {
        let content = ConflictParser.serialize(chunks: chunks)
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        do {
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write resolved conflict: \(error)")
        }
    }
    
    @objc private func markAsResolvedClicked() {
        Task {
            do {
                try await GitService.shared.stageFile(filePath, in: repoPath)
                await MainActor.run {
                    delegate?.didResolveConflict(in: filePath)
                }
            } catch {
                print("Failed to stage resolved file: \(error)")
            }
        }
    }
}
