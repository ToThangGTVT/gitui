// MARK: - StashesPresenter.swift

import Foundation

protocol StashesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didClickSaveStash(message: String)
    func didClickApplyStash(_ stash: GitStash)
    func didClickPopStash(_ stash: GitStash)
    func didClickDropStash(_ stash: GitStash)
    func didClickClearStashes()
}

class StashesPresenter: StashesPresenterProtocol, StashesInteractorOutputProtocol {
    
    private weak var view: StashesViewProtocol?
    private let interactor: StashesInteractorInputProtocol
    private let router: StashesRouterProtocol
    
    init(view: StashesViewProtocol, interactor: StashesInteractorInputProtocol, router: StashesRouterProtocol) {
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
        guard let path = activePath else {
            view?.showStashes([])
            return
        }
        view?.showLoading(true)
        interactor.loadStashes(repoPath: path)
    }
    
    func didClickSaveStash(message: String) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.saveStash(repoPath: path, message: message)
    }
    
    func didClickApplyStash(_ stash: GitStash) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.applyStash(repoPath: path, index: stash.index)
    }
    
    func didClickPopStash(_ stash: GitStash) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.popStash(repoPath: path, index: stash.index)
    }
    
    func didClickDropStash(_ stash: GitStash) {
        guard let path = activePath else { return }
        
        router.showConfirmation(
            title: "Drop Stash",
            message: "Are you sure you want to permanently discard the stash '\(stash.name)'? This action cannot be undone.",
            confirmButton: "Discard"
        ) { [weak self] approved in
            if approved {
                self?.view?.showLoading(true)
                self?.interactor.dropStash(repoPath: path, index: stash.index)
            }
        }
    }
    
    func didClickClearStashes() {
        guard let path = activePath else { return }
        
        router.showConfirmation(
            title: "Clear All Stashes",
            message: "Are you sure you want to permanently delete all stashes? This action cannot be undone.",
            confirmButton: "Clear All"
        ) { [weak self] approved in
            if approved {
                self?.view?.showLoading(true)
                self?.interactor.clearStashes(repoPath: path)
            }
        }
    }
    
    // MARK: - StashesInteractorOutputProtocol
    
    func didLoadStashes(_ stashes: [GitStash]) {
        view?.showLoading(false)
        view?.showStashes(stashes)
    }
    
    func didOperationSuccess(message: String) {
        view?.showLoading(false)
        router.showAlert(title: "Success", message: message, isError: false)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Stash Operation Failed", message: error.localizedDescription, isError: true)
    }
}
