import Foundation

protocol BlameInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class BlameInteractor: BlameInteractorProtocol {
    weak var presenter: BlamePresenterProtocol?
}
