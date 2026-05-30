// MARK: - ChangesPresenter.swift

import Cocoa

protocol ChangesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didSelectFile(_ file: GitFileStatus)
    func didDoubleClickFile(_ file: GitFileStatus)
    func didClickStageAll()
    func didClickUnstageAll()
    func didClickCommit(message: String)
    func didClickDiscard(_ file: GitFileStatus)
    func didClickRemoveFile(_ file: GitFileStatus)
    func didClickIgnoreFile(_ file: GitFileStatus)
    func didClickShowInFinder(_ file: GitFileStatus)
}

class ChangesPresenter: ChangesPresenterProtocol, ChangesInteractorOutputProtocol {
    
    private weak var view: ChangesViewProtocol?
    private let interactor: ChangesInteractorInputProtocol
    private let router: ChangesRouterProtocol
    private var stagedCount: Int = 0
    
    init(view: ChangesViewProtocol, interactor: ChangesInteractorInputProtocol, router: ChangesRouterProtocol) {
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
            view?.showStagedFiles([])
            view?.showUnstagedFiles([])
            view?.clearDiff()
            return
        }
        view?.showLoading(true)
        interactor.loadStatus(repoPath: path)
    }
    
    func didSelectFile(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.loadDiff(repoPath: path, file: file)
    }
    
    func didDoubleClickFile(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        if file.isStaged {
            interactor.unstageFile(repoPath: path, file: file)
        } else {
            interactor.stageFile(repoPath: path, file: file)
        }
    }
    
    func didClickStageAll() {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.stageAll(repoPath: path)
    }
    
    func didClickUnstageAll() {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.unstageAll(repoPath: path)
    }
    
    func didClickCommit(message: String) {
        guard let path = activePath else { return }
        guard stagedCount > 0 else {
            router.showWarning(title: "Nothing to Commit", message: "No files are staged. Please stage your changes before committing.")
            return
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            router.showAlert(title: "Empty Commit Message", message: "Please enter a valid commit message before committing.")
            return
        }
        view?.showLoading(true)
        interactor.commit(repoPath: path, message: trimmed)
    }
    
    func didClickDiscard(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.discardFile(repoPath: path, file: file)
    }
    
    func didClickRemoveFile(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        interactor.removeFile(repoPath: path, file: file)
    }
    
    func didClickIgnoreFile(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        interactor.ignoreFile(repoPath: path, file: file)
    }
    
    func didClickShowInFinder(_ file: GitFileStatus) {
        guard let path = activePath else { return }
        let fullPath = (path as NSString).appendingPathComponent(file.path)
        NSWorkspace.shared.selectFile(fullPath, inFileViewerRootedAtPath: path)
    }
    
    // MARK: - ChangesInteractorOutputProtocol
    
    func didLoadStatus(staged: [GitFileStatus], unstaged: [GitFileStatus]) {
        stagedCount = staged.count
        view?.showLoading(false)
        view?.showStagedFiles(staged)
        view?.showUnstagedFiles(unstaged)
    }
    
    func didLoadDiff(text: String, file: String) {
        view?.showLoading(false)
        view?.showDiffText(text, for: file)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Git Operation Failed", message: error.localizedDescription)
    }
    
    func didCommitSuccessfully() {
        view?.showLoading(false)
        // Refresh the whole status, reset commit message view is done in VC
    }
}
