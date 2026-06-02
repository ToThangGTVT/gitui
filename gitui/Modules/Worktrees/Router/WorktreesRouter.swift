import Cocoa

protocol WorktreesRouterProtocol: AnyObject {
    // Add navigation methods
}

class WorktreesRouter: WorktreesRouterProtocol {
    weak var viewController: NSViewController?
    weak var presenter: WorktreesPresenterProtocol?
}
