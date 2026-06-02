import Foundation

protocol BlamePresenterProtocol: AnyObject {
    func viewDidLoad()
}

class BlamePresenter: BlamePresenterProtocol {
    weak var view: BlameViewProtocol?
    var interactor: BlameInteractorProtocol
    var router: BlameRouterProtocol
    
    init(view: BlameViewProtocol, interactor: BlameInteractorProtocol, router: BlameRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
