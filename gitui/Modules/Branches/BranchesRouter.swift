// MARK: - BranchesRouter.swift

import Cocoa

protocol BranchesRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
    func showConfirmation(title: String, message: String, confirmButton: String, completion: @escaping (Bool) -> Void)
    func showPrompt(title: String, message: String, placeholder: String, completion: @escaping (String?) -> Void)
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
}
