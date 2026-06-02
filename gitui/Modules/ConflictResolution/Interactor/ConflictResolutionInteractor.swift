import Foundation

protocol ConflictResolutionInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class ConflictResolutionInteractor: ConflictResolutionInteractorProtocol {
    weak var presenter: ConflictResolutionPresenterProtocol?
}
