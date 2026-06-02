import Foundation

protocol BlamePresenterProtocol: AnyObject {
    func viewDidLoad()
    func loadBlame(for filePath: String)
}

protocol BlameInteractorOutputProtocol: AnyObject {
    func didLoadBlame(_ lines: [GitBlameLine])
    func didFailToLoadBlame(error: Error)
}

class BlamePresenter: BlamePresenterProtocol, BlameInteractorOutputProtocol {
    weak var view: BlameViewProtocol?
    var interactor: BlameInteractorProtocol
    var router: BlameRouterProtocol
    
    private var currentFilePath: String?
    
    init(view: BlameViewProtocol, interactor: BlameInteractorProtocol, router: BlameRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        if let path = currentFilePath {
            loadBlame(for: path)
        }
    }
    
    func loadBlame(for filePath: String) {
        self.currentFilePath = filePath
        view?.showLoading(true)
        interactor.fetchBlame(for: filePath, repoPath: RepositoryStore.shared.getActiveRepositoryPath() ?? "")
    }
    
    func didLoadBlame(_ lines: [GitBlameLine]) {
        view?.showLoading(false)
        view?.showBlameLines(lines)
    }
    
    func didFailToLoadBlame(error: Error) {
        view?.showLoading(false)
        // Router should show error
    }
}
