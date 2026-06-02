import Foundation

protocol SubmodulesPresenterProtocol: AnyObject {
    func viewDidLoad()
}

class SubmodulesPresenter: SubmodulesPresenterProtocol {
    weak var view: SubmodulesViewProtocol?
    var interactor: SubmodulesInteractorProtocol
    var router: SubmodulesRouterProtocol
    
    init(view: SubmodulesViewProtocol, interactor: SubmodulesInteractorProtocol, router: SubmodulesRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
