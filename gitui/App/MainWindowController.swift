// MARK: - MainWindowController.swift

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate, NSSplitViewDelegate {
    
    @IBOutlet weak var sidebarContainer: NSView!
    @IBOutlet weak var mainContainer: NSView!
    
    private var sidebarVC: NSViewController?
    private var currentTabVC: NSViewController?
    private var activeRepoPath: String?
    
    // Split view persistence
    private var splitPersistence: SplitViewPersistence?
    @IBOutlet weak var mainSplitView: NSSplitView!
    
    // UI Elements for main workarea
    private var headerContainer: NSView!
    private var segmentedControl: NSSegmentedControl!
    private var repoTitleLabel: NSTextField!
    private var tabContentContainer: NSView!
    private var placeholderView: NSView!
    
    override var windowNibName: NSNib.Name? {
        return "MainWindowController"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.center()
        
        // Wire split view persistence + delegate
        if mainSplitView != nil {
            mainSplitView.delegate = self
            splitPersistence = SplitViewPersistence(splitView: mainSplitView, key: "gitflow.split.main")
        }
        
        setupCustomToolbar()
        setupWorkspaceUI()
        loadSidebar()
        
        // Listen for active repository changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleRepoChanged(_:)), name: .activeRepositoryChanged, object: nil)
        
        // Load initial state
        updateWorkspaceState(path: RepositoryStore.shared.getActiveRepositoryPath())
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Restore divider positions once the window is visible and has a valid frame
        DispatchQueue.main.async { [weak self] in
            self?.splitPersistence?.restoreDividerPositions()
            self?.splitPersistence?.restoreCollapsedState(defaultWidth: 220)
        }
    }
    
    private func setupWorkspaceUI() {
        mainContainer.wantsLayer = true
        mainContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 1. Header Container
        headerContainer = NSView()
        headerContainer.wantsLayer = true
        headerContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(headerContainer)
        
        // Bottom border line for header
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gitFlowBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(border)
        
        // Repo Title
        repoTitleLabel = NSTextField(labelWithString: "No Repository Open")
        repoTitleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        repoTitleLabel.textColor = NSColor.labelColor
        repoTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(repoTitleLabel)
        
        // Segmented Control
        segmentedControl = NSSegmentedControl()
        segmentedControl.segmentStyle = .texturedRounded
        segmentedControl.segmentCount = 6
        segmentedControl.setLabel("Changes", forSegment: 0)
        segmentedControl.setLabel("History", forSegment: 1)
        segmentedControl.setLabel("Branches", forSegment: 2)
        segmentedControl.setLabel("Stashes", forSegment: 3)
        segmentedControl.setLabel("Remotes", forSegment: 4)
        segmentedControl.setLabel("Tags", forSegment: 5)
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged(_:))
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(segmentedControl)
        
        // 2. Tab Content Container
        tabContentContainer = NSView()
        tabContentContainer.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(tabContentContainer)
        
        // 3. Placeholder View
        setupPlaceholderView()
        
        // Layout constraints
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 55),
            
            border.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            repoTitleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            repoTitleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            
            segmentedControl.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            segmentedControl.leadingAnchor.constraint(greaterThanOrEqualTo: repoTitleLabel.trailingAnchor, constant: 20),
            segmentedControl.widthAnchor.constraint(equalToConstant: 520),
            
            tabContentContainer.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            tabContentContainer.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            tabContentContainer.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            tabContentContainer.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor)
        ])
    }
    
    private var toolbarContainer: NSView!
    
    private func setupCustomToolbar() {
        guard let contentView = window?.contentView, let splitView = mainSplitView else { return }
        
        // Remove splitView's original XIB constraints and re-add it
        splitView.removeFromSuperview()
        contentView.addSubview(splitView)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        
        toolbarContainer = NSView()
        toolbarContainer.wantsLayer = true
        toolbarContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarContainer)
        
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 15
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(leftStack)
        
        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.spacing = 15
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(rightStack)
        
        let leftButtons = [
            ("Commit", "plus.circle"),
            ("Pull", "arrow.down.circle"),
            ("Push", "arrow.up.circle"),
            ("Fetch", "arrow.clockwise.circle"),
            ("Branch", "arrow.triangle.branch"),
            ("Merge", "arrow.triangle.merge"),
            ("Stash", "archivebox")
        ]
        
        for b in leftButtons {
            leftStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1, action: nil))
        }
        
        let rightButtons = [
            ("View Remote", "globe"),
            ("Show in Finder", "folder"),
            ("Terminal", "terminal"),
            ("Settings", "gearshape")
        ]
        
        for b in rightButtons {
            rightStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1, action: nil))
        }
        
        // Bottom border
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.gridColor.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(border)
        
        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 60),
            
            leftStack.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 20),
            leftStack.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -20),
            rightStack.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            
            border.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            splitView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func createToolbarButton(title: String, symbolName: String, action: Selector?) -> NSButton {
        let button = NSButton()
        button.title = title
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?.withSymbolConfiguration(config)
        } else {
            button.image = NSImage(named: NSImage.actionTemplateName)
        }
        button.imagePosition = .imageAbove
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 11)
        button.contentTintColor = NSColor.controlAccentColor
        button.target = self
        button.action = action
        return button
    }
    
    private func setupPlaceholderView() {
        placeholderView = NSView()
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.addSubview(container)
        
        let imageView = NSImageView()
        imageView.image = NSImage(named: NSImage.actionTemplateName)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        let title = NSTextField(labelWithString: "Welcome to GitFlow")
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.textColor = NSColor.labelColor
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)
        
        let subtitle = NSTextField(labelWithString: "Open, clone, or initialize a Git repository from the sidebar to get started.")
        subtitle.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = NSColor.secondaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitle)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor),
            container.leadingAnchor.constraint(equalTo: placeholderView.leadingAnchor, constant: 40),
            container.trailingAnchor.constraint(equalTo: placeholderView.trailingAnchor, constant: -40),
            
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 64),
            imageView.heightAnchor.constraint(equalToConstant: 64),
            
            title.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    private func loadSidebar() {
        let sidebar = SidebarModule.build()
        sidebar.view.pinToEdges(of: sidebarContainer)
        sidebarVC = sidebar
    }
    
    @objc private func handleRepoChanged(_ notification: Notification) {
        let path = RepositoryStore.shared.getActiveRepositoryPath()
        DispatchQueue.main.async { [weak self] in
            self?.updateWorkspaceState(path: path)
        }
    }
    
    private func updateWorkspaceState(path: String?) {
        self.activeRepoPath = path
        
        if let path = path {
            placeholderView.removeFromSuperview()
            headerContainer.isHidden = false
            tabContentContainer.isHidden = false
            
            let url = URL(fileURLWithPath: path)
            repoTitleLabel.stringValue = url.lastPathComponent
            
            // Reload the current active tab
            selectTab(index: segmentedControl.selectedSegment)
        } else {
            headerContainer.isHidden = true
            tabContentContainer.isHidden = true
            
            if placeholderView.superview == nil {
                mainContainer.addSubview(placeholderView)
                NSLayoutConstraint.activate([
                    placeholderView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
                    placeholderView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
                    placeholderView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
                    placeholderView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor)
                ])
            }
        }
    }
    
    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        selectTab(index: sender.selectedSegment)
    }
    
    private func selectTab(index: Int) {
        guard activeRepoPath != nil else { return }
        
        currentTabVC?.view.removeFromSuperview()
        currentTabVC?.removeFromParent()
        
        let newVC: NSViewController
        
        switch index {
        case 0:
            newVC = ChangesModule.build()
        case 1:
            newVC = HistoryModule.build()
        case 2:
            newVC = BranchesModule.build()
        case 3:
            newVC = StashesModule.build()
        case 4:
            newVC = RemotesModule.build()
        case 5:
            newVC = TagsModule.build()
        default:
            return
        }
        
        newVC.view.pinToEdges(of: tabContentContainer)
        window?.contentViewController?.addChild(newVC)
        currentTabVC = newVC
    }
    
    // MARK: - NSSplitViewDelegate
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 180 // Sidebar min width
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.bounds.width - 400 // Content area min width
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        splitPersistence?.saveDividerPositions()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(self)
        return true
    }
}
