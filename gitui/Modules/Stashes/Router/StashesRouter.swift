// MARK: - StashesRouter.swift

import Cocoa

protocol StashesRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
    func showConfirmation(title: String, message: String, confirmButton: String, completion: @escaping (Bool) -> Void)
}

class StashesRouter: StashesRouterProtocol {
    
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
}
