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
    @IBOutlet weak var headerContainer: NSView!
    @IBOutlet weak var segmentedControl: NSSegmentedControl!
    @IBOutlet weak var repoTitleLabel: NSTextField!
    @IBOutlet weak var branchButton: NSButton!
    @IBOutlet weak var branchContainer: NSView!
    @IBOutlet weak var syncStatusLabel: NSTextField!
    private var syncStatusContainer: NSView!
    @IBOutlet weak var tabContentContainer: NSView!
    @IBOutlet weak var headerBorder: NSView!
    @IBOutlet weak var customToolbar: CustomToolbarView!
    @IBOutlet weak var fileSearchField: NSSearchField!
    private var placeholderView: NSView!
    private var cloneWelcomeButton: NSButton!
    
    private var customTabBar: CustomTabBarView!
    
    override var windowNibName: NSNib.Name? {
        return "MainWindowController"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.styleMask.insert(.fullSizeContentView)
        window?.isMovableByWindowBackground = true
        window?.center()
        
        // Wire split view persistence + delegate
        if mainSplitView != nil {
            mainSplitView.delegate = self
            splitPersistence = SplitViewPersistence(splitView: mainSplitView, key: "gitflow.split.main")
        }
        
        customToolbar.delegate = self
        if fileSearchField != nil {
            fileSearchField.delegate = self
        }
        setupWorkspaceUI()
        loadSidebar()
        
        // Listen for active repository changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleRepoChanged(_:)), name: .activeRepositoryChanged, object: nil)
        
        // Listen for file system changes in active repo
        NotificationCenter.default.addObserver(self, selector: #selector(handleFilesChanged), name: .repositoryFilesChanged, object: nil)
        
        // Refresh when app becomes active
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        
        // Load initial state
        updateWorkspaceState(path: RepositoryStore.shared.getActiveRepositoryPath())
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Restore divider positions once the window is visible and has a valid frame
        DispatchQueue.main.async { [weak self] in
            self?.splitPersistence?.restoreDividerPositions()
            self?.splitPersistence?.restoreCollapsedState(defaultWidth: 244)
        }
    }
    
    private func setupWorkspaceUI() {
        if let window = self.window {
            window.isOpaque = true
            window.backgroundColor = NSColor.gitFlowBackground
        }
        
        mainContainer.wantsLayer = true
        mainContainer.layer?.backgroundColor = NSColor.clear.cgColor
        
        headerContainer.wantsLayer = true
        headerContainer.layer?.backgroundColor = NSColor.clear.cgColor
        
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        
        branchContainer.wantsLayer = true
        branchContainer.layer?.cornerRadius = 8
        branchContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        
        branchButton.isBordered = false
        branchButton.contentTintColor = NSColor.m3Primary
        branchButton.font = NSFont.m3Label
        branchButton.target = self
        branchButton.action = #selector(branchButtonClicked(_:))
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            branchButton.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Branch")?.withSymbolConfiguration(config)
        }
        branchButton.imagePosition = .imageLeading
        
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged(_:))
        segmentedControl.isHidden = true
        
        customTabBar = CustomTabBarView()
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        customTabBar.tabs = ["Changes", "History", "Branches", "Stashes", "Remotes", "Tags"]
        customTabBar.delegate = self
        headerContainer.addSubview(customTabBar)
        
        NSLayoutConstraint.activate([
            customTabBar.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            customTabBar.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            customTabBar.heightAnchor.constraint(equalToConstant: 38)
        ])
        
        // Constrain the header border width to visually mimic a 3-column layout where
        // the left pane of ChangesViewController is 400px wide.
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBorder.widthAnchor.constraint(equalToConstant: 400).isActive = true
        
        placeholderView = WelcomePlaceholderView()
        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        cloneWelcomeButton = NSButton(title: "Clone Repository…", target: self, action: #selector(cloneWelcomeClicked))
        cloneWelcomeButton.bezelStyle = .push
        cloneWelcomeButton.isHidden = true
        cloneWelcomeButton.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(cloneWelcomeButton)
        NSLayoutConstraint.activate([
            cloneWelcomeButton.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            cloneWelcomeButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor, constant: -40),
            cloneWelcomeButton.widthAnchor.constraint(equalToConstant: 180),
        ])
        
        // --- Custom Title Bar Layout ---
        if let contentView = window?.contentView {
            // Remove them from their original parent (e.g. headerContainer or titlebar-view)
            repoTitleLabel.removeFromSuperview()
            branchContainer.removeFromSuperview()
            syncStatusLabel.removeFromSuperview()
            
            // Create a horizontal stack view
            // Create wrapper container for sync status
            syncStatusContainer = NSView()
            syncStatusContainer.translatesAutoresizingMaskIntoConstraints = false
            syncStatusContainer.wantsLayer = true
            syncStatusContainer.layer?.cornerRadius = 8
            syncStatusContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            
            syncStatusLabel.translatesAutoresizingMaskIntoConstraints = false
            syncStatusContainer.addSubview(syncStatusLabel)
            
            NSLayoutConstraint.activate([
                syncStatusLabel.leadingAnchor.constraint(equalTo: syncStatusContainer.leadingAnchor, constant: 8),
                syncStatusLabel.trailingAnchor.constraint(equalTo: syncStatusContainer.trailingAnchor, constant: -8),
                syncStatusLabel.centerYAnchor.constraint(equalTo: syncStatusContainer.centerYAnchor),
                syncStatusContainer.heightAnchor.constraint(equalToConstant: 22)
            ])
            
            let titleStack = NSStackView(views: [repoTitleLabel, branchContainer, syncStatusContainer])
            titleStack.orientation = .horizontal
            titleStack.alignment = .centerY
            titleStack.spacing = 8
            titleStack.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(titleStack)
            
            // Center the stack view in the window
            NSLayoutConstraint.activate([
                titleStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                titleStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                titleStack.heightAnchor.constraint(equalToConstant: 26)
            ])
            
            // Ensure proper typography for the title
            repoTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            repoTitleLabel.textColor = NSColor.labelColor
        }
        // -------------------------------
    }

    @objc private func cloneWelcomeClicked() {
        guard let window = self.window else { return }
        CloneViewController.show(from: window) { clonedPath in
            RepositoryStore.shared.setActiveRepository(path: clonedPath)
        }
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
        
        // Refresh ahead/behind stats
        Task {
            let aheadBehind = await GitService.shared.getAheadBehind(in: path)
            await MainActor.run { [weak self] in
                self?.updateSyncStatus(ahead: aheadBehind.ahead, behind: aheadBehind.behind)
            }
        }
        
        // Notify modules to refresh data (NOT rebuild views)
        NotificationCenter.default.post(name: .repositoryContentShouldRefresh, object: nil)
        // Notify sidebar to update line stats
        NotificationCenter.default.post(name: .sidebarShouldRefreshStats, object: nil)
    }
    
    @objc private func handleAppDidBecomeActive() {
        // Refresh the current active repo content and all repos in the sidebar
        handleFilesChanged()
    }
    
    private func updateWorkspaceState(path: String?) {
        self.activeRepoPath = path
        
        if let path = path {
            placeholderView.removeFromSuperview()
            cloneWelcomeButton.isHidden = true
            headerContainer.isHidden = false
            tabContentContainer.isHidden = false
            
            let url = URL(fileURLWithPath: path)
            repoTitleLabel.stringValue = url.lastPathComponent
            
            // Fetch and display current branch name
            updateBranchLabel(for: path, repoName: url.lastPathComponent)
            
            // Start watching this repo for file changes
            FileWatcherService.shared.watch(repoPath: path)
            
            // Reload the current active tab
            customTabBar.setSelectedIndex(0, animated: false)
            selectTab(index: 0)
        } else {
            headerContainer.isHidden = true
            tabContentContainer.isHidden = true
            cloneWelcomeButton.isHidden = false

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
        return 244 // Sidebar width
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.bounds.width - 400 // Content area min width
    }
    
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()
    }
    
    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        // Prevent sidebar from resizing when the window is resized
        return view != splitView.subviews.first
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
        
        GitFetchViewController.show(repoPath: path, from: self.window) { [weak self] options in
            do {
                try await GitService.shared.fetch(remote: nil, options: options, in: path)
                await MainActor.run {
                    self?.showToolbarAlert(title: "Fetch Complete", message: "Successfully fetched.", isError: false)
                    let repoName = URL(fileURLWithPath: path).lastPathComponent
                    self?.updateBranchLabel(for: path, repoName: repoName)
                    self?.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self?.showToolbarAlert(title: "Fetch Failed", message: error.localizedDescription, isError: true)
                }
                throw error
            }
        }
    }
    
    @objc private func toolbarPullClicked() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        Task {
            let currentBranch = await detectCurrentBranch(in: path)
            await MainActor.run {
                GitPullViewController.show(defaultBranch: currentBranch ?? "main", repoPath: path, from: self.window) { [weak self] remote, branch, options in
                    try await self?.performPull(remote: remote, branch: branch, options: options, repoPath: path)
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
            let remotes = (try? await GitService.shared.getRemotes(in: path)) ?? []
            let branches = (try? await GitService.shared.getBranches(in: path)) ?? []
            
            let remoteNames = remotes.isEmpty ? ["origin"] : remotes.map { $0.name }
            let branchNames = branches.isEmpty ? [currentBranch ?? "main"] : branches.map { $0.name }
            
            await MainActor.run { 
                self.showPushDialog(defaultBranch: currentBranch ?? "main", remotes: remoteNames, branches: branchNames, repoPath: path) 
            }
        }
    }

    private func showPushDialog(defaultBranch: String, remotes: [String], branches: [String], repoPath: String) {
        guard let window = self.window else { return }
        let alert = NSAlert()
        alert.messageText = "Push to Remote"
        alert.addButton(withTitle: "Push")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 84))

        let remoteField = popupField("Remote:", items: remotes, selectedValue: remotes.first ?? "origin", y: 58, in: container)
        let branchField = popupField("Branch:", items: branches, selectedValue: defaultBranch, y: 32, in: container)

        let forceBox = NSButton(checkboxWithTitle: "Force push (--force-with-lease)", target: nil, action: nil)
        forceBox.frame = NSRect(x: 65, y: 4, width: 230, height: 22)
        forceBox.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(forceBox)

        alert.accessoryView = container
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn else { return }
            let remote = remoteField.titleOfSelectedItem?.trimmingCharacters(in: .whitespaces) ?? ""
            let branch = branchField.titleOfSelectedItem?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !remote.isEmpty && !branch.isEmpty else { return }
            GitPushProgressViewController.show(remote: remote, branch: branch,
                                               force: forceBox.state == .on,
                                               repoPath: repoPath, from: self.window) { [weak self] success in
                guard let self = self else { return }
                let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
                self.updateBranchLabel(for: repoPath, repoName: repoName)
                self.refreshCurrentTab()
            }
        }
    }

    // Helper: creates a label+field row at a given y offset
    @discardableResult
    private func labeledField(_ label: String, value: String, y: CGFloat, in parent: NSView) -> NSTextField {
        let lbl = NSTextField(labelWithString: label)
        lbl.frame = NSRect(x: 0, y: y, width: 60, height: 22)
        lbl.font = NSFont.systemFont(ofSize: 13)
        parent.addSubview(lbl)

        let field = NSTextField()
        field.frame = NSRect(x: 65, y: y, width: 230, height: 22)
        field.stringValue = value
        field.font = NSFont.systemFont(ofSize: 13)
        parent.addSubview(field)
        return field
    }

    // Helper: creates a label+popup row at a given y offset
    @discardableResult
    private func popupField(_ label: String, items: [String], selectedValue: String, y: CGFloat, in parent: NSView) -> NSPopUpButton {
        let lbl = NSTextField(labelWithString: label)
        lbl.frame = NSRect(x: 0, y: y, width: 60, height: 22)
        lbl.font = NSFont.systemFont(ofSize: 13)
        parent.addSubview(lbl)

        let popup = NSPopUpButton(frame: NSRect(x: 65, y: y, width: 230, height: 22), pullsDown: false)
        popup.addItems(withTitles: items)
        if items.contains(selectedValue) {
            popup.selectItem(withTitle: selectedValue)
        } else if !selectedValue.isEmpty {
            popup.addItem(withTitle: selectedValue)
            popup.selectItem(withTitle: selectedValue)
        }
        popup.font = NSFont.systemFont(ofSize: 13)
        parent.addSubview(popup)
        return popup
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
                    self.repoTitleLabel.font = NSFont.m3Title
                    self.branchButton.title = " \(branch) ▾"
                    self.branchButton.superview?.isHidden = false
                    
                    // Update sync status
                    self.updateSyncStatus(ahead: aheadBehind.ahead, behind: aheadBehind.behind)
                } else {
                    self.branchButton.superview?.isHidden = true
                    self.syncStatusContainer?.isHidden = true
                }
            }
        }
    }
    
    private func updateSyncStatus(ahead: Int, behind: Int) {
        customToolbar.setPushBadge(count: ahead)
        customToolbar.setPullBadge(count: behind)
        
        guard ahead > 0 || behind > 0 else {
            syncStatusContainer?.isHidden = true
            return
        }
        
        let result = NSMutableAttributedString()
        
        if ahead > 0 {
            result.append(NSAttributedString(string: "↑\(ahead)", attributes: [
                .foregroundColor: NSColor.m3Primary,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            ]))
        }
        if ahead > 0 && behind > 0 {
            result.append(NSAttributedString(string: "  ", attributes: [
                .font: NSFont.systemFont(ofSize: 12)
            ]))
        }
        if behind > 0 {
            result.append(NSAttributedString(string: "↓\(behind)", attributes: [
                .foregroundColor: NSColor.m3Primary,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            ]))
        }
        
        syncStatusLabel.attributedStringValue = result
        syncStatusContainer?.isHidden = false
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
    
    @objc private func toolbarBranchClicked() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        
        Task {
            let currentBranch = await detectCurrentBranch(in: path)
            guard let activeBranch = currentBranch else {
                await MainActor.run {
                    self.showToolbarAlert(title: "Error", message: "Unable to detect the current branch.", isError: true)
                }
                return
            }
            
            await MainActor.run {
                self.showCreateBranchDialog(sourceBranch: activeBranch) { name, checkout in
                    self.performCreateBranch(name: name, source: activeBranch, checkout: checkout, repoPath: path)
                }
            }
        }
    }
    
    private func showCreateBranchDialog(sourceBranch: String, completion: @escaping (String, Bool) -> Void) {
        guard let window = self.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Create Branch"
        alert.informativeText = "Create a new branch starting from '\(sourceBranch)'."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let nameLabel = NSTextField(labelWithString: "Branch Name:")
        nameLabel.frame = NSRect(x: 0, y: 34, width: 90, height: 22)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        accessoryView.addSubview(nameLabel)
        
        let nameField = NSTextField()
        nameField.frame = NSRect(x: 95, y: 34, width: 200, height: 22)
        nameField.font = NSFont.systemFont(ofSize: 13)
        nameField.placeholderString = "e.g. feature-login"
        accessoryView.addSubview(nameField)
        
        let checkoutCheckbox = NSButton(checkboxWithTitle: "Checkout new branch immediately", target: nil, action: nil)
        checkoutCheckbox.frame = NSRect(x: 95, y: 4, width: 200, height: 22)
        checkoutCheckbox.state = .on
        checkoutCheckbox.font = NSFont.systemFont(ofSize: 12)
        accessoryView.addSubview(checkoutCheckbox)
        
        alert.accessoryView = accessoryView
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let shouldCheckout = checkoutCheckbox.state == .on
                
                guard !name.isEmpty else {
                    self.showToolbarAlert(title: "Invalid Input", message: "Branch name is required.", isError: true)
                    return
                }
                completion(name, shouldCheckout)
            }
        }
    }
    
    private func performCreateBranch(name: String, source: String, checkout: Bool, repoPath: String) {
        Task {
            do {
                try await GitService.shared.createBranch(name: name, startPoint: source, checkout: checkout, in: repoPath)
                await MainActor.run {
                    self.showToolbarAlert(title: "Branch Created", message: "Successfully created branch '\(name)' from '\(source)'.", isError: false)
                    let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
                    self.updateBranchLabel(for: repoPath, repoName: repoName)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Create Branch Failed", message: error.localizedDescription, isError: true)
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
    
    private func performPull(remote: String, branch: String, options: [String], repoPath: String) async throws {
        do {
            try await GitService.shared.pull(remote: remote, branch: branch, options: options, in: repoPath)
            await MainActor.run {
                self.showToolbarAlert(title: "Pull Complete", message: "Successfully pulled \(branch) from '\(remote)'.", isError: false)
                let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
                self.updateBranchLabel(for: repoPath, repoName: repoName)
                self.refreshCurrentTab()
            }
        } catch {
            await MainActor.run {
                self.showToolbarAlert(title: "Pull Failed", message: error.localizedDescription, isError: true)
            }
            throw error
        }
    }
    
    private func performPush(remote: String, branch: String, repoPath: String) {
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
        GitPushProgressViewController.show(remote: remote, branch: branch, repoPath: repoPath, from: self.window) { [weak self] success in
            guard let self = self else { return }
            self.updateBranchLabel(for: repoPath, repoName: repoName)
            self.refreshCurrentTab()
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
        remoteLabel.font = NSFont.systemFont(ofSize: 13)
        accessoryView.addSubview(remoteLabel)
        
        let remoteField = NSTextField()
        remoteField.frame = NSRect(x: 65, y: 32, width: 230, height: 22)
        remoteField.stringValue = "origin"
        remoteField.font = NSFont.systemFont(ofSize: 13)
        remoteField.placeholderString = "e.g. origin"
        accessoryView.addSubview(remoteField)
        
        let branchLabel = NSTextField(labelWithString: "Branch:")
        branchLabel.frame = NSRect(x: 0, y: 4, width: 60, height: 22)
        branchLabel.font = NSFont.systemFont(ofSize: 13)
        accessoryView.addSubview(branchLabel)
        
        let branchField = NSTextField()
        branchField.frame = NSRect(x: 65, y: 4, width: 230, height: 22)
        branchField.stringValue = defaultBranch
        branchField.font = NSFont.systemFont(ofSize: 13)
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
        // No-op or handle appropriately
    }
}

// MARK: - NSSearchFieldDelegate

extension MainWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === fileSearchField else { return }
        let query = field.stringValue
        NotificationCenter.default.post(name: .fileSearchQueryChanged, object: nil, userInfo: ["query": query])
    }
}

// MARK: - CustomToolbarViewDelegate

extension MainWindowController: CustomToolbarViewDelegate {

    func toolbarDidClickCommit() {
        customTabBar.setSelectedIndex(0)
        selectTab(index: 0)
    }

    func toolbarDidClickPull() {
        toolbarPullClicked()
    }

    func toolbarDidClickPush() {
        toolbarPushClicked()
    }

    func toolbarDidClickFetch() {
        toolbarFetchClicked()
    }

    func toolbarDidClickBranch() {
        toolbarBranchClicked()
    }

    func toolbarDidClickMerge() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        Task {
            do {
                let branches = try await GitService.shared.getBranches(in: path)
                let current  = branches.first(where: { $0.isCurrent })?.name ?? "HEAD"
                let others   = branches.filter { !$0.isRemote && !$0.isCurrent }
                guard !others.isEmpty else {
                    await MainActor.run {
                        self.showToolbarAlert(title: "No Branches", message: "No other local branches to merge.", isError: true)
                    }
                    return
                }
                await MainActor.run {
                    self.showMergeDialog(currentBranch: current, branches: others) { branch in
                        self.performMerge(branch: branch, into: current, repoPath: path)
                    }
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Error", message: error.localizedDescription, isError: true)
                }
            }
        }
    }

    func toolbarDidClickStash() {
        guard let path = activeRepoPath else {
            showToolbarAlert(title: "No Repository", message: "Please open a repository first.", isError: true)
            return
        }
        guard let window = self.window else { return }

        let alert = NSAlert()
        alert.messageText = "Stash Changes"
        alert.informativeText = "Save your working directory changes to the stash."
        alert.addButton(withTitle: "Stash")
        alert.addButton(withTitle: "Cancel")

        let msgField = NSTextField()
        msgField.frame = NSRect(x: 0, y: 0, width: 280, height: 22)
        msgField.font = NSFont.systemFont(ofSize: 13)
        msgField.placeholderString = "Stash message (optional)..."
        alert.accessoryView = msgField

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn else { return }
            let msg = msgField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                do {
                    try await GitService.shared.stashSave(message: msg.isEmpty ? nil : msg, in: path)
                    await MainActor.run {
                        self.customTabBar.setSelectedIndex(3)
                        self.selectTab(index: 3)
                    }
                } catch {
                    await MainActor.run {
                        self.showToolbarAlert(title: "Stash Failed", message: error.localizedDescription, isError: true)
                    }
                }
            }
        }
    }

    func toolbarDidClickViewRemote() {
        customTabBar.setSelectedIndex(4)
        selectTab(index: 4)
    }

    func toolbarDidClickShowInFinder() {
        toolbarShowInFinderClicked()
    }

    func toolbarDidClickTerminal() {
        toolbarTerminalClicked()
    }

    func toolbarDidClickSettings() {
        guard let window = self.window else { return }
        SettingsModule.show(from: window, repoPath: activeRepoPath) { [weak self] in
            self?.refreshCurrentTab()
        }
    }
}

// MARK: - CustomTabBarDelegate

extension MainWindowController: CustomTabBarDelegate {
    func customTabBar(_ tabBar: CustomTabBarView, didSelectTabAt index: Int) {
        selectTab(index: index)
    }
}

// MARK: - CustomTabBarView

protocol CustomTabBarDelegate: AnyObject {
    func customTabBar(_ tabBar: CustomTabBarView, didSelectTabAt index: Int)
}

class CustomTabBarView: NSView {
    weak var delegate: CustomTabBarDelegate?
    
    private var buttons: [NSButton] = []
    private var selectedIndex: Int = 0
    private var selectionIndicator: NSView!
    
    var tabs: [String] = [] {
        didSet {
            setupTabs()
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupIndicator()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupIndicator()
    }
    
    private func setupIndicator() {
        self.wantsLayer = true
        selectionIndicator = NSView()
        selectionIndicator.wantsLayer = true
        selectionIndicator.layer?.backgroundColor = NSColor.systemBlue.cgColor
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionIndicator)
    }
    
    private func setupTabs() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        
        var previousButton: NSButton?
        
        for (index, title) in tabs.enumerated() {
            let btn = NSButton()
            btn.title = title
            btn.isBordered = false
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            btn.tag = index
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            updateButtonAppearance(btn, isSelected: index == selectedIndex)
            
            addSubview(btn)
            buttons.append(btn)
            
            NSLayoutConstraint.activate([
                btn.centerYAnchor.constraint(equalTo: centerYAnchor),
                btn.heightAnchor.constraint(equalTo: heightAnchor)
            ])
            
            if let prev = previousButton {
                btn.leadingAnchor.constraint(equalTo: prev.trailingAnchor, constant: 16).isActive = true
            } else {
                btn.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            }
            
            previousButton = btn
        }
        
        if let last = previousButton {
            last.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        }
        
        updateIndicatorPosition(animated: false)
    }
    
    @objc private func tabClicked(_ sender: NSButton) {
        setSelectedIndex(sender.tag, animated: true)
        delegate?.customTabBar(self, didSelectTabAt: sender.tag)
    }
    
    func setSelectedIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < buttons.count else { return }
        selectedIndex = index
        
        for (i, btn) in buttons.enumerated() {
            updateButtonAppearance(btn, isSelected: i == index)
        }
        
        updateIndicatorPosition(animated: animated)
    }
    
    private func updateButtonAppearance(_ btn: NSButton, isSelected: Bool) {
        let titleAttr = NSMutableAttributedString(string: btn.title)
        let range = NSRange(location: 0, length: titleAttr.length)
        
        titleAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: isSelected ? .bold : .medium), range: range)
        titleAttr.addAttribute(.foregroundColor, value: isSelected ? NSColor.systemBlue : NSColor.secondaryLabelColor, range: range)
        
        btn.attributedTitle = titleAttr
    }
    
    private var indicatorConstraints: [NSLayoutConstraint] = []
    
    private func updateIndicatorPosition(animated: Bool) {
        guard selectedIndex < buttons.count else { return }
        let selectedBtn = buttons[selectedIndex]
        
        NSLayoutConstraint.deactivate(indicatorConstraints)
        
        indicatorConstraints = [
            selectionIndicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 2),
            selectionIndicator.centerXAnchor.constraint(equalTo: selectedBtn.centerXAnchor),
            selectionIndicator.widthAnchor.constraint(equalTo: selectedBtn.widthAnchor, constant: 4)
        ]
        
        NSLayoutConstraint.activate(indicatorConstraints)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                self.layoutSubtreeIfNeeded()
            }
        } else {
            self.layoutSubtreeIfNeeded()
        }
    }
}

// MARK: - Merge helpers

extension MainWindowController {

    private func showMergeDialog(currentBranch: String, branches: [GitBranch],
                                 completion: @escaping (String) -> Void) {
        guard let window = self.window else { return }
        let alert = NSAlert()
        alert.messageText = "Merge Branch"
        alert.informativeText = "Select a branch to merge into '\(currentBranch)'."
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        popup.addItems(withTitles: branches.map { $0.name })
        alert.accessoryView = popup

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn,
               let selected = popup.titleOfSelectedItem, !selected.isEmpty {
                completion(selected)
            }
        }
    }

    private func performMerge(branch: String, into current: String, repoPath: String) {
        Task {
            do {
                try await GitService.shared.merge(branch: branch, in: repoPath)
                await MainActor.run {
                    self.showToolbarAlert(title: "Merge Complete",
                                         message: "Merged '\(branch)' into '\(current)'.", isError: false)
                    self.refreshCurrentTab()
                }
            } catch {
                await MainActor.run {
                    self.showToolbarAlert(title: "Merge Failed", message: error.localizedDescription, isError: true)
                }
            }
        }
    }
}

