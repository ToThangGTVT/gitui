import Foundation

protocol InteractiveRebasePresenterProtocol: AnyObject {
    func viewDidLoad()
    func updateItemAction(at index: Int, action: RebaseAction)
    func moveItem(from sourceIndex: Int, to destinationIndex: Int)
    func startRebase()
    func abortRebase()
}

class InteractiveRebasePresenter: InteractiveRebasePresenterProtocol, InteractiveRebaseInteractorOutputProtocol {
    weak var view: InteractiveRebaseViewProtocol?
    var interactor: InteractiveRebaseInteractorProtocol
    var router: InteractiveRebaseRouterProtocol
    var ontoHash: String?
    private var items: [RebaseTodoItem] = []
    
    init(view: InteractiveRebaseViewProtocol, interactor: InteractiveRebaseInteractorProtocol, router: InteractiveRebaseRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        guard let onto = ontoHash, let repoPath = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        view?.showLoading(true)
        interactor.loadCommits(onto: onto, repoPath: repoPath)
    }
    
    func updateItemAction(at index: Int, action: RebaseAction) {
        guard index >= 0 && index < items.count else { return }
        items[index].action = action
        view?.showItems(items)
    }
    
    func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < items.count else { return }
        guard destinationIndex >= 0 && destinationIndex <= items.count else { return }
        
        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        view?.showItems(items)
    }
    
    func startRebase() {
        guard let onto = ontoHash, let repoPath = RepositoryStore.shared.getActiveRepositoryPath() else { return }
        view?.showLoading(true)
        interactor.executeRebase(onto: onto, items: items, repoPath: repoPath)
    }
    
    func abortRebase() {
        router.close()
    }
    
    // MARK: - Interactor Output
    
    func didLoadCommits(_ commits: [RebaseTodoItem]) {
        self.items = commits
        view?.showLoading(false)
        view?.showItems(items)
    }
    
    func didFailToLoadCommits(error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Error", message: error.localizedDescription)
    }
    
    func didExecuteRebaseSuccessfully() {
        view?.showLoading(false)
        NotificationCenter.default.post(name: .repositoryFilesChanged, object: nil)
        router.close()
    }
    
    func didFailToExecuteRebase(error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Rebase Failed", message: error.localizedDescription)
    }
}
