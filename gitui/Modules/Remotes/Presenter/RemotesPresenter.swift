// MARK: - RemotesPresenter.swift

import Cocoa

protocol RemotesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didClickAddRemote(name: String, url: String)
    func didClickRemoveRemote(_ remote: GitRemote)
    func didClickFetch(_ remote: GitRemote)
    func didClickPull(_ remote: GitRemote, branch: String)
    func didClickPush(_ remote: GitRemote, branch: String)
}

class RemotesPresenter: RemotesPresenterProtocol, RemotesInteractorOutputProtocol {
    
    private weak var view: RemotesViewProtocol?
    private let interactor: RemotesInteractorInputProtocol
    private let router: RemotesRouterProtocol
    
    init(view: RemotesViewProtocol, interactor: RemotesInteractorInputProtocol, router: RemotesRouterProtocol) {
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
            view?.showRemotes([])
            return
        }
        view?.showLoading(true)
        interactor.loadRemotes(repoPath: path)
    }
    
    func didClickAddRemote(name: String, url: String) {
        guard let path = activePath else { return }
        
        let cleanName = name.trimimmingWhitespaces()
        let cleanUrl = url.trimimmingWhitespaces()
        
        guard !cleanName.isEmpty && !cleanUrl.isEmpty else {
            router.showAlert(title: "Invalid Input", message: "Both remote name and URL are required.", isError: true)
            return
        }
        
        view?.showLoading(true)
        interactor.addRemote(repoPath: path, name: cleanName, url: cleanUrl)
    }
    
    func didClickRemoveRemote(_ remote: GitRemote) {
        guard let path = activePath else { return }
        
        router.showConfirmation(
            title: "Remove Remote",
            message: "Are you sure you want to remove remote '\(remote.name)'? This only removes the remote reference from your local repository configuration.",
            confirmButton: "Remove"
        ) { [weak self] approved in
            if approved {
                self?.view?.showLoading(true)
                self?.interactor.removeRemote(repoPath: path, name: remote.name)
            }
        }
    }
    
    func didClickFetch(_ remote: GitRemote) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.fetchRemote(repoPath: path, name: remote.name)
    }
    
    func didClickPull(_ remote: GitRemote, branch: String) {
        guard let path = activePath else { return }
        let cleanBranch = branch.trimimmingWhitespaces()
        guard !cleanBranch.isEmpty else {
            router.showAlert(title: "Branch Required", message: "Please specify which remote branch to pull.", isError: true)
            return
        }
        view?.showLoading(true)
        interactor.pullRemote(repoPath: path, name: remote.name, branch: cleanBranch)
    }
    
    func didClickPush(_ remote: GitRemote, branch: String) {
        guard let path = activePath else { return }
        let cleanBranch = branch.trimimmingWhitespaces()
        guard !cleanBranch.isEmpty else {
            router.showAlert(title: "Branch Required", message: "Please specify which local branch to push.", isError: true)
            return
        }
        
        let window = (view as? NSViewController)?.view.window
        GitPushProgressViewController.show(remote: remote.name, branch: cleanBranch, repoPath: path, from: window) { [weak self] success in
            self?.refresh()
        }
    }
    
    // MARK: - RemotesInteractorOutputProtocol
    
    func didLoadRemotes(_ remotes: [GitRemote]) {
        view?.showLoading(false)
        view?.showRemotes(remotes)
    }
    
    func didOperationSuccess(message: String) {
        view?.showLoading(false)
        router.showAlert(title: "Success", message: message, isError: false)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Remote Operation Failed", message: error.localizedDescription, isError: true)
    }
}

private extension String {
    func trimimmingWhitespaces() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
