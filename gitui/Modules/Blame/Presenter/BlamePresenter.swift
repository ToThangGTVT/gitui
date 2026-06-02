import Foundation

protocol BlamePresenterProtocol: AnyObject {
    func viewDidLoad()
    func loadBlame(for filePath: String, at commitHash: String?)
}

protocol BlameInteractorOutputProtocol: AnyObject {
    func didLoadBlame(_ lines: [GitBlameLine])
    func didFailToLoadBlame(error: Error)
}

class BlamePresenter: BlamePresenterProtocol, BlameInteractorOutputProtocol {
    weak var view: BlameViewProtocol?
    var interactor: BlameInteractorProtocol
    var router: BlameRouterProtocol
    
    var currentFilePath: String?
    var currentCommitHash: String?
    
    init(view: BlameViewProtocol, interactor: BlameInteractorProtocol, router: BlameRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        if let path = currentFilePath {
            loadBlame(for: path, at: currentCommitHash)
        }
    }
    
    func loadBlame(for filePath: String, at commitHash: String?) {
        self.currentFilePath = filePath
        self.currentCommitHash = commitHash
        view?.showLoading(true)
        interactor.fetchBlame(for: filePath, at: commitHash, repoPath: RepositoryStore.shared.getActiveRepositoryPath() ?? "")
    }
    
    func didLoadBlame(_ lines: [GitBlameLine]) {
        view?.showLoading(false)
        view?.showBlameLines(lines)
    }
    
    func didFailToLoadBlame(error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Failed to load Blame", message: error.localizedDescription, isError: true)
    }
}
