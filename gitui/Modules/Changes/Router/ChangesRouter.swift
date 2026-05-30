// MARK: - ChangesRouter.swift

import Cocoa

protocol ChangesRouterProtocol: AnyObject {
    func showAlert(title: String, message: String)
    func showWarning(title: String, message: String)
}

class ChangesRouter: ChangesRouterProtocol {
    
    weak var viewController: NSViewController?
    
    func showAlert(title: String, message: String) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
    func showWarning(title: String, message: String) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.icon = NSImage(named: NSImage.cautionName)
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}
