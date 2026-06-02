import Cocoa

protocol SearchRouterProtocol: AnyObject {
    // Add navigation methods
}

class SearchRouter: SearchRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: SearchPresenterProtocol?
}
