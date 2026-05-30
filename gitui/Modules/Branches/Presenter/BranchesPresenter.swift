// MARK: - BranchesPresenter.swift

import Cocoa

protocol BranchesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refresh()
    func didDoubleClickNode(_ node: BranchNode)
    func didClickMerge(_ node: BranchNode)
    func didClickDelete(_ node: BranchNode)
    func didClickRename(_ node: BranchNode, to newName: String)
    func didRequestRename(_ node: BranchNode)
    func didClickPush(_ node: BranchNode)
}

class BranchesPresenter: BranchesPresenterProtocol, BranchesInteractorOutputProtocol {
    
    private weak var view: BranchesViewProtocol?
    private let interactor: BranchesInteractorInputProtocol
    private let router: BranchesRouterProtocol
    
    init(view: BranchesViewProtocol, interactor: BranchesInteractorInputProtocol, router: BranchesRouterProtocol) {
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
            view?.showBranchTree([])
            return
        }
        view?.showLoading(true)
        interactor.loadBranchesAndTags(repoPath: path)
    }
    
    func didDoubleClickNode(_ node: BranchNode) {
        guard let path = activePath else { return }
        guard !node.isHeader && !node.isTag else { return }
        view?.showLoading(true)
        interactor.checkout(repoPath: path, branchName: node.name)
    }
    
    func didClickMerge(_ node: BranchNode) {
        guard let path = activePath else { return }
        guard !node.isHeader else { return }
        view?.showLoading(true)
        interactor.merge(repoPath: path, branchName: node.name)
    }
    
    func didClickDelete(_ node: BranchNode) {
        guard let path = activePath else { return }
        guard !node.isHeader else { return }
        
        // Show confirmation before deletion!
        router.showConfirmation(
            title: "Delete Branch",
            message: "Are you sure you want to delete branch '\(node.name)'? This action cannot be undone.",
            confirmButton: "Delete"
        ) { [weak self] approved in
            if approved {
                self?.view?.showLoading(true)
                self?.interactor.deleteBranch(repoPath: path, branchName: node.name, force: true)
            }
        }
    }
    
    func didRequestRename(_ node: BranchNode) {
        let currentName = node.name.components(separatedBy: "/").last ?? node.name
        router.showPrompt(
            title: "Rename Branch",
            message: "Enter the new name for '\(currentName)':",
            placeholder: currentName
        ) { [weak self] newName in
            if let val = newName, !val.isEmpty {
                self?.didClickRename(node, to: val)
            }
        }
    }
    
    func didClickRename(_ node: BranchNode, to newName: String) {
        guard let path = activePath else { return }
        guard !node.isHeader else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        view?.showLoading(true)
        interactor.renameBranch(repoPath: path, oldName: node.name, newName: trimmed)
    }
    
    func didClickPush(_ node: BranchNode) {
        guard let path = activePath else { return }
        guard !node.isHeader && !node.isRemote else { return }
        
        let window = (view as? NSViewController)?.view.window
        GitPushProgressViewController.show(remote: "origin", branch: node.name, repoPath: path, from: window) { [weak self] success in
            self?.refresh()
        }
    }
    
    // MARK: - BranchesInteractorOutputProtocol
    
    func didLoadBranchesAndTags(branches: [GitBranch], tags: [GitTag]) {
        view?.showLoading(false)
        
        // Construct standard Sourcetree branch outline hierarchy!
        let localHeader = BranchNode(name: "LOCAL", isHeader: true)
        let remoteHeader = BranchNode(name: "REMOTE", isHeader: true, isRemote: true)
        let tagHeader = BranchNode(name: "TAGS", isHeader: true, isTag: true)
        
        for branch in branches {
            if branch.isRemote {
                remoteHeader.children.append(BranchNode(name: branch.name, isHeader: false, isRemote: true, isCurrent: branch.isCurrent))
            } else {
                localHeader.children.append(BranchNode(name: branch.name, isHeader: false, isRemote: false, isCurrent: branch.isCurrent))
            }
        }
        
        for tag in tags {
            tagHeader.children.append(BranchNode(name: tag.name, isHeader: false, isTag: true))
        }
        
        var roots: [BranchNode] = []
        if !localHeader.children.isEmpty { roots.append(localHeader) }
        if !remoteHeader.children.isEmpty { roots.append(remoteHeader) }
        if !tagHeader.children.isEmpty { roots.append(tagHeader) }
        
        view?.showBranchTree(roots)
    }
    
    func didOperationSuccess(message: String) {
        view?.showLoading(false)
        router.showAlert(title: "Success", message: message, isError: false)
    }
    
    func didOperationError(_ error: Error) {
        view?.showLoading(false)
        router.showAlert(title: "Branch Operation Failed", message: error.localizedDescription, isError: true)
    }
}
