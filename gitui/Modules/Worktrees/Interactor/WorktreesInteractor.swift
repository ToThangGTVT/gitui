import Foundation

protocol WorktreesInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class WorktreesInteractor: WorktreesInteractorProtocol {
    weak var presenter: WorktreesPresenterProtocol?
}
