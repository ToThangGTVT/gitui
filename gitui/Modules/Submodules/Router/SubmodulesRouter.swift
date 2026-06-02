import Cocoa

protocol SubmodulesRouterProtocol: AnyObject {
    // Add navigation methods
}

class SubmodulesRouter: SubmodulesRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: SubmodulesPresenterProtocol?
}
