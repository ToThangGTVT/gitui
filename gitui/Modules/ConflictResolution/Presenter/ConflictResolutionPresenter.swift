import Foundation

protocol ConflictResolutionPresenterProtocol: AnyObject {
    func viewDidLoad()
}

class ConflictResolutionPresenter: ConflictResolutionPresenterProtocol {
    weak var view: ConflictResolutionViewProtocol?
    var interactor: ConflictResolutionInteractorProtocol
    var router: ConflictResolutionRouterProtocol
    
    init(view: ConflictResolutionViewProtocol, interactor: ConflictResolutionInteractorProtocol, router: ConflictResolutionRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
