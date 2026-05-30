// MARK: - SidebarPresenter.swift

import Foundation

protocol SidebarPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func filterBookmarks(query: String)
    func didSelectRepository(_ bookmark: RepositoryBookmark)
    func didMoveRepository(from: Int, to: Int)
    func didClickRemoveRepository(at index: Int)
    func didClickOpen()
    func didClickInit()
    func didClickClone()
}

class SidebarPresenter: SidebarPresenterProtocol, SidebarInteractorOutputProtocol {
    
    private weak var view: SidebarViewProtocol?
    private let interactor: SidebarInteractorInputProtocol
    private let router: SidebarRouterProtocol
    
    private var allBookmarks: [RepositoryBookmark] = []
    private var activePath: String?
    private var currentQuery: String = ""
    
    init(view: SidebarViewProtocol, interactor: SidebarInteractorInputProtocol, router: SidebarRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        refresh()
    }
    
    func refresh() {
        view?.showLoading(true)
        interactor.loadBookmarks()
    }
    
    func filterBookmarks(query: String) {
        currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFiltering()
    }
    
    private func applyFiltering() {
        if currentQuery.isEmpty {
            view?.showBookmarks(allBookmarks, activePath: activePath)
        } else {
            let filtered = allBookmarks.filter {
                $0.name.localizedCaseInsensitiveContains(currentQuery) ||
                $0.path.localizedCaseInsensitiveContains(currentQuery)
            }
            view?.showBookmarks(filtered, activePath: activePath)
        }
    }
    
    func didSelectRepository(_ bookmark: RepositoryBookmark) {
        interactor.selectRepository(path: bookmark.path)
    }
    
    func didMoveRepository(from: Int, to: Int) {
        interactor.moveRepository(from: from, to: to)
    }
    
    func didClickRemoveRepository(at index: Int) {
        interactor.removeRepository(at: index)
    }
    
    func didClickOpen() {
        router.showOpenPanel { [weak self] path in
            guard let path = path else { return }
            let name = URL(fileURLWithPath: path).lastPathComponent
            self?.interactor.addRepository(name: name, path: path)
        }
    }
    
    func didClickInit() {
        router.showOpenPanel { [weak self] path in
            guard let path = path else { return }
            self?.view?.showLoading(true)
            self?.interactor.initRepository(at: path)
        }
    }
    
    func didClickClone() {
        router.showClonePrompt { [weak self] url, path in
            guard let url = url, let path = path else { return }
            self?.view?.showLoading(true)
            self?.interactor.cloneRepository(url: url, targetPath: path)
        }
    }
    
    // MARK: - SidebarInteractorOutputProtocol
    
    func didLoadBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?) {
        view?.showLoading(false)
        self.allBookmarks = bookmarks
        self.activePath = activePath
        applyFiltering()
    }
    
    func didCloneSuccess(name: String, path: String) {
        view?.showLoading(false)
        router.showAlert(title: "Repository Cloned", message: "Successfully cloned repository to \(path)", isError: false)
    }
    
    func didInitSuccess(name: String, path: String) {
        view?.showLoading(false)
        router.showAlert(title: "Repository Initialized", message: "Successfully initialized a new Git repository at \(path)", isError: false)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Operation Failed", message: error.localizedDescription, isError: true)
    }
}
