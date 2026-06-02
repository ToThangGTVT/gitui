import Foundation

protocol WorktreesPresenterProtocol: AnyObject {
    func viewDidLoad()
}

class WorktreesPresenter: WorktreesPresenterProtocol {
    weak var view: WorktreesViewProtocol?
    var interactor: WorktreesInteractorProtocol
    var router: WorktreesRouterProtocol
    
    init(view: WorktreesViewProtocol, interactor: WorktreesInteractorProtocol, router: WorktreesRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
