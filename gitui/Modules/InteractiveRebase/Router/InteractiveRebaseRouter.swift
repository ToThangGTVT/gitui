import Cocoa

protocol InteractiveRebaseRouterProtocol: AnyObject {
    func showAlert(title: String, message: String)
    func close()
}

class InteractiveRebaseRouter: InteractiveRebaseRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: InteractiveRebasePresenterProtocol?
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if let window = viewController?.view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
    
    func close() {
        if let window = viewController?.view.window {
            window.sheetParent?.endSheet(window)
            window.close()
        }
    }
}
