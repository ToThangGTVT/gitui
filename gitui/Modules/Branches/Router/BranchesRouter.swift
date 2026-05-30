// MARK: - BranchesRouter.swift

import Cocoa

protocol BranchesRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
    func showConfirmation(title: String, message: String, confirmButton: String, completion: @escaping (Bool) -> Void)
    func showPrompt(title: String, message: String, placeholder: String, completion: @escaping (String?) -> Void)
    func showCreateBranchDialog(sourceBranch: String, completion: @escaping (String?, Bool) -> Void)
}

class BranchesRouter: BranchesRouterProtocol {
    
    weak var viewController: NSViewController?
    
    func showAlert(title: String, message: String, isError: Bool) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
    func showConfirmation(title: String, message: String, confirmButton: String, completion: @escaping (Bool) -> Void) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }
    
    func showPrompt(title: String, message: String, placeholder: String, completion: @escaping (String?) -> Void) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        inputField.placeholderString = placeholder
        alert.accessoryView = inputField
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                completion(inputField.stringValue)
            } else {
                completion(nil)
            }
        }
    }
    
    func showCreateBranchDialog(sourceBranch: String, completion: @escaping (String?, Bool) -> Void) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Create Branch"
        alert.informativeText = "Create a new branch starting from '\(sourceBranch)'."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let nameLabel = NSTextField(labelWithString: "Branch Name:")
        nameLabel.frame = NSRect(x: 0, y: 34, width: 90, height: 22)
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        accessoryView.addSubview(nameLabel)
        
        let nameField = NSTextField()
        nameField.frame = NSRect(x: 95, y: 34, width: 200, height: 22)
        nameField.font = NSFont.systemFont(ofSize: 12)
        nameField.placeholderString = "e.g. feature-login"
        accessoryView.addSubview(nameField)
        
        let checkoutCheckbox = NSButton(checkboxWithTitle: "Checkout new branch immediately", target: nil, action: nil)
        checkoutCheckbox.frame = NSRect(x: 95, y: 4, width: 200, height: 22)
        checkoutCheckbox.state = .on
        checkoutCheckbox.font = NSFont.systemFont(ofSize: 11)
        accessoryView.addSubview(checkoutCheckbox)
        
        alert.accessoryView = accessoryView
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let shouldCheckout = checkoutCheckbox.state == .on
                completion(name.isEmpty ? nil : name, shouldCheckout)
            } else {
                completion(nil, false)
            }
        }
    }
}
