import Cocoa

protocol BlameRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
}

class BlameRouter: BlameRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: BlamePresenterProtocol?
    
    func showAlert(title: String, message: String, isError: Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = isError ? .critical : .informational
        alert.addButton(withTitle: "OK")
        
        if let window = viewController?.view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}
