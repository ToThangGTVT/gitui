import Foundation

protocol SearchPresenterProtocol: AnyObject {
    func viewDidLoad()
}

class SearchPresenter: SearchPresenterProtocol {
    weak var view: SearchViewProtocol?
    var interactor: SearchInteractorProtocol
    var router: SearchRouterProtocol
    
    init(view: SearchViewProtocol, interactor: SearchInteractorProtocol, router: SearchRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
