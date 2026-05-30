// MARK: - HistoryRouter.swift

import Cocoa

protocol HistoryRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
    func copyToClipboard(text: String)
    func populateContextMenu(_ menu: NSMenu, for commit: CommitNode)
}

class HistoryRouter: HistoryRouterProtocol {
    
    weak var viewController: NSViewController?
    weak var presenter: HistoryPresenterProtocol?
    
    func showAlert(title: String, message: String, isError: Bool) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func populateContextMenu(_ menu: NSMenu, for commit: CommitNode) {
        let hash = commit.hash
        
        // 1. Checkout
        let checkoutItem = NSMenuItem(title: "Checkout this commit (detached HEAD)", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        checkoutItem.target = self
        checkoutItem.representedObject = CommitAction.checkout(hash: hash)
        menu.addItem(checkoutItem)
        
        // 2. Create Branch
        let branchItem = NSMenuItem(title: "Create branch here...", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        branchItem.target = self
        branchItem.representedObject = CommitAction.createBranch(hash: hash, name: "")
        menu.addItem(branchItem)
        
        // 3. Create Tag
        let tagItem = NSMenuItem(title: "Create tag here...", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        tagItem.target = self
        tagItem.representedObject = CommitAction.createTag(hash: hash, name: "", message: "")
        menu.addItem(tagItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Cherry-pick
        let cherryItem = NSMenuItem(title: "Cherry-pick onto current branch", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        cherryItem.target = self
        cherryItem.representedObject = CommitAction.cherryPick(hash: hash)
        menu.addItem(cherryItem)
        
        // 5. Revert
        let revertItem = NSMenuItem(title: "Revert this commit", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        revertItem.target = self
        revertItem.representedObject = CommitAction.revert(hash: hash)
        menu.addItem(revertItem)
        
        // 6. Reset (Submenu)
        let resetItem = NSMenuItem(title: "Reset current branch to here", action: nil, keyEquivalent: "")
        let resetSubmenu = NSMenu()
        
        let softItem = NSMenuItem(title: "Soft", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        softItem.target = self
        softItem.representedObject = CommitAction.reset(hash: hash, mode: .soft)
        resetSubmenu.addItem(softItem)
        
        let mixedItem = NSMenuItem(title: "Mixed", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        mixedItem.target = self
        mixedItem.representedObject = CommitAction.reset(hash: hash, mode: .mixed)
        resetSubmenu.addItem(mixedItem)
        
        let hardItem = NSMenuItem(title: "Hard", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        hardItem.target = self
        hardItem.representedObject = CommitAction.reset(hash: hash, mode: .hard)
        resetSubmenu.addItem(hardItem)
        
        resetItem.submenu = resetSubmenu
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 7. Copy Hash
        let copyHashItem = NSMenuItem(title: "Copy commit hash", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        copyHashItem.target = self
        copyHashItem.representedObject = CommitAction.copyHash(hash: hash, short: false)
        menu.addItem(copyHashItem)
        
        // 8. Copy Short Hash
        let copyShortItem = NSMenuItem(title: "Copy short hash", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        copyShortItem.target = self
        copyShortItem.representedObject = CommitAction.copyHash(hash: hash, short: true)
        menu.addItem(copyShortItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 9. Compare with Working Tree
        let compareItem = NSMenuItem(title: "Compare with working tree", action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        compareItem.target = self
        compareItem.representedObject = CommitAction.compareWithWorkingTree(hash: hash)
        menu.addItem(compareItem)
        
        // 10. Show in Finder
        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(showInFinderClicked(_:)), keyEquivalent: "")
        finderItem.target = self
        menu.addItem(finderItem)
    }
    
    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? CommitAction else { return }
        
        switch action {
        case .createBranch(let hash, _):
            promptForBranch(at: hash)
        case .createTag(let hash, _, _):
            promptForTag(at: hash)
        default:
            presenter?.handleAction(action)
        }
    }
    
    @objc private func showInFinderClicked(_ sender: NSMenuItem) {
        guard let path = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
    
    private func promptForBranch(at hash: String) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Create Branch"
        alert.informativeText = "Create a new branch at commit \(String(hash.prefix(7)))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create Branch")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        inputField.placeholderString = "Branch Name"
        alert.accessoryView = inputField
        
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                let branchName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !branchName.isEmpty {
                    self.presenter?.handleAction(.createBranch(hash: hash, name: branchName))
                } else {
                    self.showAlert(title: "Invalid Name", message: "Branch name cannot be empty.", isError: true)
                }
            }
        }
    }
    
    private func promptForTag(at hash: String) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Create Tag"
        alert.informativeText = "Create a new tag at commit \(String(hash.prefix(7)))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create Tag")
        alert.addButton(withTitle: "Cancel")
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 56))
        
        let nameField = NSTextField(frame: NSRect(x: 0, y: 32, width: 240, height: 24))
        nameField.placeholderString = "Tag Name (e.g. v1.0.0)"
        container.addSubview(nameField)
        
        let messageField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        messageField.placeholderString = "Tag Message (optional)"
        container.addSubview(messageField)
        
        alert.accessoryView = container
        
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                let tagName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let tagMessage = messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !tagName.isEmpty {
                    self.presenter?.handleAction(.createTag(hash: hash, name: tagName, message: tagMessage))
                } else {
                    self.showAlert(title: "Invalid Name", message: "Tag name cannot be empty.", isError: true)
                }
            }
        }
    }
}
