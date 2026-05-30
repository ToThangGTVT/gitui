// MARK: - TagsPresenter.swift

import Foundation

protocol TagsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didClickCreateTag(name: String)
    func didClickDeleteTag(_ tag: GitTag)
    func didClickPushTag(_ tag: GitTag, remote: String)
}

class TagsPresenter: TagsPresenterProtocol, TagsInteractorOutputProtocol {
    
    private weak var view: TagsViewProtocol?
    private let interactor: TagsInteractorInputProtocol
    private let router: TagsRouterProtocol
    
    init(view: TagsViewProtocol, interactor: TagsInteractorInputProtocol, router: TagsRouterProtocol) {
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
            view?.showTags([])
            return
        }
        view?.showLoading(true)
        interactor.loadTags(repoPath: path)
    }
    
    func didClickCreateTag(name: String) {
        guard let path = activePath else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            router.showAlert(title: "Empty Name", message: "Please enter a valid tag name.", isError: true)
            return
        }
        view?.showLoading(true)
        interactor.createTag(repoPath: path, name: trimmed)
    }
    
    func didClickDeleteTag(_ tag: GitTag) {
        guard let path = activePath else { return }
        
        router.showConfirmation(
            title: "Delete Tag",
            message: "Are you sure you want to delete tag '\(tag.name)'? This action cannot be undone.",
            confirmButton: "Delete"
        ) { [weak self] approved in
            if approved {
                self?.view?.showLoading(true)
                self?.interactor.deleteTag(repoPath: path, name: tag.name)
            }
        }
    }
    
    func didClickPushTag(_ tag: GitTag, remote: String) {
        guard let path = activePath else { return }
        let trimmedRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackRemote = trimmedRemote.isEmpty ? "origin" : trimmedRemote
        
        view?.showLoading(true)
        interactor.pushTag(repoPath: path, name: tag.name, remote: fallbackRemote)
    }
    
    // MARK: - TagsInteractorOutputProtocol
    
    func didLoadTags(_ tags: [GitTag]) {
        view?.showLoading(false)
        view?.showTags(tags)
    }
    
    func didOperationSuccess(message: String) {
        view?.showLoading(false)
        router.showAlert(title: "Success", message: message, isError: false)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Tag Operation Failed", message: error.localizedDescription, isError: true)
    }
}
