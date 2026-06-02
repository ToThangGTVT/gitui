import Cocoa

protocol InteractiveRebaseRouterProtocol: AnyObject {
    // Add navigation methods
}

class InteractiveRebaseRouter: InteractiveRebaseRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: InteractiveRebasePresenterProtocol?
}
