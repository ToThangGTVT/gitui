import Foundation

protocol InteractiveRebaseInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class InteractiveRebaseInteractor: InteractiveRebaseInteractorProtocol {
    weak var presenter: InteractiveRebasePresenterProtocol?
}
