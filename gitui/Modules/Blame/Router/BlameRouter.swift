import Cocoa

protocol BlameRouterProtocol: AnyObject {
    // Add navigation methods
}

class BlameRouter: BlameRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: BlamePresenterProtocol?
}
