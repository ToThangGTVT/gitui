import Foundation

protocol SearchInteractorProtocol: AnyObject {
    // Add methods for presenter to request data
}

class SearchInteractor: SearchInteractorProtocol {
    weak var presenter: SearchPresenterProtocol?
}
