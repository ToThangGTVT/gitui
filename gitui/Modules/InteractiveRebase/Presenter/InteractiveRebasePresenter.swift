import Foundation

protocol InteractiveRebasePresenterProtocol: AnyObject {
    func viewDidLoad()
}

class InteractiveRebasePresenter: InteractiveRebasePresenterProtocol {
    weak var view: InteractiveRebaseViewProtocol?
    var interactor: InteractiveRebaseInteractorProtocol
    var router: InteractiveRebaseRouterProtocol
    
    init(view: InteractiveRebaseViewProtocol, interactor: InteractiveRebaseInteractorProtocol, router: InteractiveRebaseRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        // Inform interactor or update view
    }
}
