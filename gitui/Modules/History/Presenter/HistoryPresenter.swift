// MARK: - HistoryPresenter.swift

import Cocoa

protocol HistoryPresenterProtocol: AnyObject {
    var hasMoreCommits: Bool { get }
    func viewDidLoad()
    func refresh()
    func loadMore()
    func didSelectCommit(_ commit: CommitNode)
    func handleAction(_ action: CommitAction)
    func showContextMenu(for commit: CommitNode, menu: NSMenu)
}

class HistoryPresenter: HistoryPresenterProtocol, HistoryInteractorOutputProtocol {
    
    private weak var view: HistoryViewProtocol?
    private let interactor: HistoryInteractorInputProtocol
    private let router: HistoryRouterProtocol
    
    private var commits: [CommitNode] = []
    private var currentLimit = 200
    private var isLoadingMore = false
    var hasMoreCommits = true
    
    init(view: HistoryViewProtocol, interactor: HistoryInteractorInputProtocol, router: HistoryRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    private var activePath: String? {
        return RepositoryStore.shared.getActiveRepositoryPath()
    }
    
    func viewDidLoad() {
        refresh()
    }
    
    func refresh() {
        currentLimit = 200
        hasMoreCommits = true
        loadHistory()
    }
    
    func loadMore() {
        guard !isLoadingMore, hasMoreCommits else { return }
        isLoadingMore = true
        currentLimit += 200
        loadHistory()
    }
    
    private func loadHistory() {
        guard let path = activePath else {
            view?.showHistory([])
            return
        }
        view?.showLoading(true)
        interactor.loadHistory(repoPath: path, limit: currentLimit)
    }
    
    func didSelectCommit(_ commit: CommitNode) {
        // Broad-cast selection update to view details panel
        view?.updateCommitDetails(commit)
    }
    
    func handleAction(_ action: CommitAction) {
        guard let path = activePath else { return }
        
        switch action {
        case .checkout(let hash):
            view?.showLoading(true)
            interactor.checkout(repoPath: path, hash: hash)
            
        case .createBranch(let hash, let name):
            view?.showLoading(true)
            interactor.createBranch(repoPath: path, hash: hash, name: name)
            
        case .createTag(let hash, let name, let message):
            view?.showLoading(true)
            interactor.createTag(repoPath: path, hash: hash, name: name, message: message)
            
        case .cherryPick(let hash):
            view?.showLoading(true)
            interactor.cherryPick(repoPath: path, hash: hash)
            
        case .revert(let hash):
            view?.showLoading(true)
            interactor.revert(repoPath: path, hash: hash)
            
        case .reset(let hash, let mode):
            view?.showLoading(true)
            interactor.reset(repoPath: path, hash: hash, mode: mode)
            
        case .copyHash(let hash, let short):
            let textToCopy = short ? String(hash.prefix(7)) : hash
            router.copyToClipboard(text: textToCopy)
            
        case .compareWithWorkingTree(let hash):
            // Show modal comparing with working tree or log success/info
            router.showAlert(title: "Compare with Working Tree", message: "Comparing working tree with commit \(hash).", isError: false)
        }
    }
    
    func showContextMenu(for commit: CommitNode, menu: NSMenu) {
        router.populateContextMenu(menu, for: commit)
    }
    
    // MARK: - HistoryInteractorOutputProtocol
    
    func didLoadHistory(_ commits: [CommitNode]) {
        // We reached the end of history if increasing the limit didn't give us any more commits
        if commits.count <= self.commits.count && currentLimit > 200 {
            self.hasMoreCommits = false
        }
        
        self.commits = commits
        self.isLoadingMore = false
        view?.showLoading(false)
        view?.showHistory(commits)
    }
    
    func didOperationSuccess(message: String) {
        view?.showLoading(false)
        router.showAlert(title: "Success", message: message, isError: false)
        refresh() // Refresh log after checkout/branch/tag/merge
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        self.isLoadingMore = false
        router.showAlert(title: "Operation Failed", message: error.localizedDescription, isError: true)
    }
}
