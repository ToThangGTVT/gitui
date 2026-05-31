// MARK: - ChangesPresenter.swift

import Cocoa

protocol ChangesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didSelectFile(_ file: GitFileStatus)
    func didDoubleClickFile(_ file: GitFileStatus)
    func didClickStageAll()
    func didClickUnstageAll()
    func didClickCommit(message: String, amend: Bool)
    func didRequestLastCommitMessage()
    func didClickStageHunk(patch: String)
    func didClickDiscardHunk(patch: String)
    func didClickUnstageHunk(patch: String)
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
    private var currentSelectedFile: GitFileStatus? = nil
    private var needsAutoReloadDiff = false

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
        currentSelectedFile = file
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

    func didClickCommit(message: String, amend: Bool) {
        guard let path = activePath else { return }
        if !amend && stagedCount == 0 {
            router.showWarning(title: "Nothing to Commit", message: "No files are staged. Please stage your changes before committing.")
            return
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            router.showAlert(title: "Empty Commit Message", message: "Please enter a valid commit message before committing.")
            return
        }
        view?.showLoading(true)
        interactor.commit(repoPath: path, message: trimmed, amend: amend)
    }

    func didRequestLastCommitMessage() {
        guard let path = activePath else { return }
        interactor.loadLastCommitMessage(repoPath: path)
    }

    func didClickStageHunk(patch: String) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        needsAutoReloadDiff = true
        interactor.stageHunk(repoPath: path, patch: patch)
    }

    func didClickDiscardHunk(patch: String) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        needsAutoReloadDiff = true
        interactor.discardHunk(repoPath: path, patch: patch)
    }

    func didClickUnstageHunk(patch: String) {
        guard let path = activePath else { return }
        view?.showLoading(true)
        needsAutoReloadDiff = true
        interactor.unstageHunk(repoPath: path, patch: patch)
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
        let hasConflicts = (staged + unstaged).contains { $0.status == "U" }
        view?.showConflictBanner(hasConflicts)

        if needsAutoReloadDiff, let file = currentSelectedFile, let path = activePath {
            needsAutoReloadDiff = false
            let found = unstaged.first { $0.path == file.path } ?? staged.first { $0.path == file.path }
            if let updated = found {
                currentSelectedFile = updated
                view?.showLoading(true)
                interactor.loadDiff(repoPath: path, file: updated)
            } else {
                view?.clearDiff()
                currentSelectedFile = nil
            }
        }
    }

    func didLoadDiff(text: String, filePath: String, isStaged: Bool) {
        view?.showLoading(false)
        view?.showDiffText(text, for: filePath, isStaged: isStaged)
    }

    func didLoadLastCommitMessage(_ message: String) {
        view?.showLastCommitMessage(message)
    }

    func didHunkOperationSuccess() {
        // loading will be hidden after the subsequent didLoadStatus callback
    }

    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        needsAutoReloadDiff = false
        router.showAlert(title: "Git Operation Failed", message: error.localizedDescription)
    }

    func didCommitSuccessfully() {
        view?.showLoading(false)
        NotificationCenter.default.post(name: .repositoryFilesChanged, object: nil)
    }
}
