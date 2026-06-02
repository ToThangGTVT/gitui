import Foundation

protocol SubmodulesInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class SubmodulesInteractor: SubmodulesInteractorProtocol {
    weak var presenter: SubmodulesPresenterProtocol?
}
