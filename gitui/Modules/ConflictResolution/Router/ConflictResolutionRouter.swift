import Cocoa

protocol ConflictResolutionRouterProtocol: AnyObject {
    // Add navigation methods
}

class ConflictResolutionRouter: ConflictResolutionRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: ConflictResolutionPresenterProtocol?
}
