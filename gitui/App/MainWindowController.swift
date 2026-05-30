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
    private var branchButton: NSButton!
    private var syncStatusLabel: NSTextField!
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
        
        // Listen for file system changes in active repo
        NotificationCenter.default.addObserver(self, selector: #selector(handleFilesChanged), name: .repositoryFilesChanged, object: nil)
        
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
        
        // Branch Button (clickable, shows sheet to switch branches)
        let branchContainer = NSView()
        branchContainer.wantsLayer = true
        branchContainer.layer?.cornerRadius = 6
        branchContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        branchContainer.translatesAutoresizingMaskIntoConstraints = false
        branchContainer.identifier = NSUserInterfaceItemIdentifier("branchContainer")
        headerContainer.addSubview(branchContainer)
        
        branchButton = NSButton()
        branchButton.isBordered = false
        branchButton.contentTintColor = NSColor.controlAccentColor
        branchButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        branchButton.target = self
        branchButton.action = #selector(branchButtonClicked(_:))
        branchButton.translatesAutoresizingMaskIntoConstraints = false
        branchContainer.isHidden = true
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            branchButton.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Branch")?.withSymbolConfiguration(config)
        }
        branchButton.imagePosition = .imageLeading
        branchContainer.addSubview(branchButton)
        
        // Sync Status Label (↑N ↓M)
        syncStatusLabel = NSTextField(labelWithString: "")
        syncStatusLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        syncStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        syncStatusLabel.isHidden = true
        headerContainer.addSubview(syncStatusLabel)
        
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
            
            branchContainer.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            branchContainer.leadingAnchor.constraint(equalTo: repoTitleLabel.trailingAnchor, constant: 10),
            branchContainer.heightAnchor.constraint(equalToConstant: 26),
            
            branchButton.leadingAnchor.constraint(equalTo: branchContainer.leadingAnchor, constant: 8),
            branchButton.trailingAnchor.constraint(equalTo: branchContainer.trailingAnchor, constant: -8),
            branchButton.centerYAnchor.constraint(equalTo: branchContainer.centerYAnchor),
            
            syncStatusLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            syncStatusLabel.leadingAnchor.constraint(equalTo: branchContainer.trailingAnchor, constant: 8),
            
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
        
        let leftButtons: [(String, String, Selector?)] = [
            ("Commit", "plus.circle", nil),
            ("Pull", "arrow.down.circle", #selector(toolbarPullClicked)),
            ("Push", "arrow.up.circle", #selector(toolbarPushClicked)),
            ("Fetch", "arrow.clockwise.circle", #selector(toolbarFetchClicked)),
            ("Branch", "arrow.triangle.branch", nil),
            ("Merge", "arrow.triangle.merge", nil),
            ("Stash", "archivebox", nil)
        ]
        
        for b in leftButtons {
            leftStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1, action: b.2))
        }
        
        let rightButtons: [(String, String, Selector?)] = [
            ("View Remote", "globe", nil),
            ("Show in Finder", "folder", #selector(toolbarShowInFinderClicked)),
            ("Terminal", "terminal", #selector(toolbarTerminalClicked)),
            ("Settings", "gearshape", nil)
        ]
        
        for b in rightButtons {
            rightStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1, action: b.2))
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
    
    @objc private func handleFilesChanged() {
        guard let path = activeRepoPath else { return }
        // Update branch label (in case of checkout)
        let repoName = URL(fileURLWithPath: path).lastPathComponent
        updateBranchLabel(for: path, repoName: repoName)
        // Notify modules to refresh data (NOT rebuild views)
        NotificationCenter.default.post(name: .repositoryContentShouldRefresh, object: nil)
        // Notify sidebar to update line stats
        NotificationCenter.default.post(name: .sidebarShouldRefreshStats, object: nil)
    }
    
    private func updateWorkspaceState(path: String?) {
        self.activeRepoPath = path
        
        if let path = path {
            placeholderView.removeFromSuperview()
            headerContainer.isHidden = false
            tabContentContainer.isHidden = false
            
            let url = URL(fileURLWithPath: path)
            repoTitleLabel.stringValue = url.lastPathComponent
            
            // Fetch and display current branch name
            updateBranchLabel(for: path, repoName: url.lastPathComponent)
            
            // Start watching this repo for file changes
            FileWatcherService.shared.watch(repoPath: path)
            
            // Reload the current active tab
            selectTab(index: segmentedControl.selectedSegment)
        } else {
            headerContainer.isHidden = true
            tabContentContainer.isHidden = true
            
            // Stop watching when no repo is active
            FileWatcherService.shared.stopWatching()
            
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
    
    // MARK: - Toolbar Actions
    
    @objc private func toolbarFetchClicked() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        
        Task {
            do {
                let remotes = try await GitService.shared.getRemotes(in: path)
                guard !remotes.isEmpty else {
                    await MainActor.run {
                        self.showToolbarAlert(title: "No Remotes", message: "This repository has no remotes configured. Add a remote in the Remotes tab first.", isError: true)
                    }
                    return
                }
                // Fetch all remotes
                for remote in remotes {
                    try await GitService.shared.fetch(remote: remote.name, in: path)
                }
                await MainActor.run {
                    self.showToolbarAlert(title: "Fetch Complete", message: "Successfully fetched from all remotes.", isError: false)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Fetch Failed", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
    
    @objc private func toolbarPullClicked() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        
        // Detect the current branch to pre-fill the dialog
        Task {
            let currentBranch = await detectCurrentBranch(in: path)
            await MainActor.run {
                self.showPullPushDialog(title: "Pull from Remote", defaultBranch: currentBranch ?? "main", confirmTitle: "Pull") { remote, branch in
                    self.performPull(remote: remote, branch: branch, repoPath: path)
                }
            }
        }
    }
    
    @objc private func toolbarPushClicked() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        
        Task {
            let currentBranch = await detectCurrentBranch(in: path)
            await MainActor.run {
                self.showPullPushDialog(title: "Push to Remote", defaultBranch: currentBranch ?? "main", confirmTitle: "Push") { remote, branch in
                    self.performPush(remote: remote, branch: branch, repoPath: path)
                }
            }
        }
    }
    
    @objc private func toolbarShowInFinderClicked() {
        guard let path = activeRepoPath else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
    
    @objc private func toolbarTerminalClicked() {
        guard let path = activeRepoPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }
    
    // MARK: - Branch Label & Switcher
    
    private func updateBranchLabel(for repoPath: String, repoName: String) {
        Task {
            let branch = await detectCurrentBranch(in: repoPath)
            let aheadBehind = await GitService.shared.getAheadBehind(in: repoPath)
            await MainActor.run {
                guard self.activeRepoPath == repoPath else { return }
                if let branch = branch {
                    self.repoTitleLabel.stringValue = repoName
                    self.repoTitleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
                    self.branchButton.title = " \(branch) ▾"
                    self.branchButton.superview?.isHidden = false
                    
                    // Update sync status
                    self.updateSyncStatus(ahead: aheadBehind.ahead, behind: aheadBehind.behind)
                } else {
                    self.branchButton.superview?.isHidden = true
                    self.syncStatusLabel.isHidden = true
                }
            }
        }
    }
    
    private func updateSyncStatus(ahead: Int, behind: Int) {
        guard ahead > 0 || behind > 0 else {
            syncStatusLabel.isHidden = true
            return
        }
        
        let result = NSMutableAttributedString()
        
        if ahead > 0 {
            result.append(NSAttributedString(string: "↑\(ahead)", attributes: [
                .foregroundColor: NSColor.systemGreen,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            ]))
        }
        if ahead > 0 && behind > 0 {
            result.append(NSAttributedString(string: "  ", attributes: [
                .font: NSFont.systemFont(ofSize: 11)
            ]))
        }
        if behind > 0 {
            result.append(NSAttributedString(string: "↓\(behind)", attributes: [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            ]))
        }
        
        syncStatusLabel.attributedStringValue = result
        syncStatusLabel.isHidden = false
    }
    
    @objc private func branchButtonClicked(_ sender: NSButton) {
        guard let path = activeRepoPath, let window = self.window else { return }
        
        Task {
            do {
                let branches = try await GitService.shared.getBranches(in: path)
                let localBranches = branches.filter { !$0.isRemote }
                await MainActor.run {
                    let sheetVC = BranchSheetViewController(branches: localBranches) { [weak self] selectedBranch in
                        self?.switchToBranch(selectedBranch, in: path)
                    }
                    
                    let sheetWindow = NSWindow(contentViewController: sheetVC)
                    sheetWindow.styleMask = [.titled, .closable]
                    sheetWindow.title = "Switch Branch"
                    sheetWindow.setContentSize(NSSize(width: 400, height: 420))
                    
                    window.beginSheet(sheetWindow, completionHandler: nil)
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Error", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
    
    private func switchToBranch(_ branch: GitBranch, in repoPath: String) {
        guard !branch.isCurrent else { return }
        Task {
            do {
                try await GitService.shared.checkout(branch: branch.name, in: repoPath)
                await MainActor.run {
                    let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
                    self.updateBranchLabel(for: repoPath, repoName: repoName)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Checkout Failed", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
    
    // MARK: - Pull/Push/Fetch Helpers
    
    private func detectCurrentBranch(in repoPath: String) async -> String? {
        do {
            let branches = try await GitService.shared.getBranches(in: repoPath)
            return branches.first(where: { $0.isCurrent })?.name
        } catch {
            return nil
        }
    }
    
    private func performPull(remote: String, branch: String, repoPath: String) {
        Task {
            do {
                try await GitService.shared.pull(remote: remote, branch: branch, in: repoPath)
                await MainActor.run {
                    self.showToolbarAlert(title: "Pull Complete", message: "Successfully pulled \(branch) from '\(remote)'.", isError: false)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Pull Failed", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
    
    private func performPush(remote: String, branch: String, repoPath: String) {
        Task {
            do {
                try await GitService.shared.push(remote: remote, branch: branch, in: repoPath)
                await MainActor.run {
                    self.showToolbarAlert(title: "Push Complete", message: "Successfully pushed \(branch) to '\(remote)'.", isError: false)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Push Failed", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
    
    private func showPullPushDialog(title: String, defaultBranch: String, confirmTitle: String, completion: @escaping (String, String) -> Void) {
        guard let window = self.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Specify the remote and branch name."
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 58))
        
        let remoteLabel = NSTextField(labelWithString: "Remote:")
        remoteLabel.frame = NSRect(x: 0, y: 32, width: 60, height: 22)
        remoteLabel.font = NSFont.systemFont(ofSize: 12)
        accessoryView.addSubview(remoteLabel)
        
        let remoteField = NSTextField()
        remoteField.frame = NSRect(x: 65, y: 32, width: 230, height: 22)
        remoteField.stringValue = "origin"
        remoteField.font = NSFont.systemFont(ofSize: 12)
        remoteField.placeholderString = "e.g. origin"
        accessoryView.addSubview(remoteField)
        
        let branchLabel = NSTextField(labelWithString: "Branch:")
        branchLabel.frame = NSRect(x: 0, y: 4, width: 60, height: 22)
        branchLabel.font = NSFont.systemFont(ofSize: 12)
        accessoryView.addSubview(branchLabel)
        
        let branchField = NSTextField()
        branchField.frame = NSRect(x: 65, y: 4, width: 230, height: 22)
        branchField.stringValue = defaultBranch
        branchField.font = NSFont.systemFont(ofSize: 12)
        branchField.placeholderString = "e.g. main"
        accessoryView.addSubview(branchField)
        
        alert.accessoryView = accessoryView
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let remote = remoteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let branch = branchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !remote.isEmpty && !branch.isEmpty else {
                    self.showToolbarAlert(title: "Invalid Input", message: "Both remote and branch name are required.", isError: true)
                    return
                }
                completion(remote, branch)
            }
        }
    }
    
    private func showToolbarAlert(title: String, message: String, isError: Bool) {
        guard let window = self.window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
    private func refreshCurrentTab() {
        selectTab(index: segmentedControl.selectedSegment)
    }
}

// MARK: - Branch Switcher Sheet

private class BranchSheetViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    private let allBranches: [GitBranch]
    private var filteredBranches: [GitBranch]
    private let onSelect: (GitBranch) -> Void
    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var checkoutButton: NSButton!
    
    init(branches: [GitBranch], onSelect: @escaping (GitBranch) -> Void) {
        self.allBranches = branches
        self.filteredBranches = branches
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 420))
        container.wantsLayer = true
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Switch Branch")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        // Current branch info
        let currentBranch = allBranches.first(where: { $0.isCurrent })
        let currentLabel = NSTextField(labelWithString: "Current: \(currentBranch?.name ?? "unknown")")
        currentLabel.font = NSFont.systemFont(ofSize: 12)
        currentLabel.textColor = NSColor.secondaryLabelColor
        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(currentLabel)
        
        // Search field
        searchField = NSSearchField()
        searchField.placeholderString = "Filter branches..."
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)
        
        // Separator
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)
        
        // Table
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 32
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = false
        tableView.doubleAction = #selector(doubleClickCheckout)
        tableView.target = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("branch"))
        column.width = 340
        tableView.addTableColumn(column)
        
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        
        // Bottom bar separator
        let bottomSep = NSView()
        bottomSep.wantsLayer = true
        bottomSep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        bottomSep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bottomSep)
        
        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cancelButton)
        
        checkoutButton = NSButton(title: "Checkout", target: self, action: #selector(checkoutClicked))
        checkoutButton.bezelStyle = .rounded
        checkoutButton.keyEquivalent = "\r"
        checkoutButton.isEnabled = false
        checkoutButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkoutButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            currentLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            currentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomSep.topAnchor),
            
            bottomSep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomSep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomSep.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            bottomSep.heightAnchor.constraint(equalToConstant: 1),
            
            checkoutButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            checkoutButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            checkoutButton.widthAnchor.constraint(equalToConstant: 90),
            
            cancelButton.trailingAnchor.constraint(equalTo: checkoutButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            cancelButton.widthAnchor.constraint(equalToConstant: 70)
        ])
        
        self.view = container
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
    
    @objc private func cancelClicked() {
        closeSheet()
    }
    
    @objc private func checkoutClicked() {
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
        var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellId
            
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                icon.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            }
            icon.contentTintColor = NSColor.secondaryLabelColor
            cell?.addSubview(icon)
            cell?.imageView = icon
            
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(label)
            cell?.textField = label
            
            let check = NSTextField(labelWithString: "")
            check.identifier = NSUserInterfaceItemIdentifier("checkmark")
            check.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            check.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(check)
            
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 12),
                icon.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18),
                
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: check.leadingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                
                check.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -12),
                check.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                check.widthAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        cell?.textField?.stringValue = branch.name
        
        if branch.isCurrent {
            cell?.textField?.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            cell?.textField?.textColor = NSColor.controlAccentColor
            cell?.imageView?.contentTintColor = NSColor.controlAccentColor
            if let check = cell?.subviews.first(where: { $0.identifier?.rawValue == "checkmark" }) as? NSTextField {
                check.stringValue = "✓"
                check.textColor = NSColor.controlAccentColor
            }
        } else {
            cell?.textField?.font = NSFont.systemFont(ofSize: 13)
            cell?.textField?.textColor = NSColor.labelColor
            cell?.imageView?.contentTintColor = NSColor.secondaryLabelColor
            if let check = cell?.subviews.first(where: { $0.identifier?.rawValue == "checkmark" }) as? NSTextField {
                check.stringValue = ""
            }
        }
        
        return cell
    }
}
