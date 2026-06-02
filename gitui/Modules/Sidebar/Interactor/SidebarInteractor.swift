// MARK: - SidebarInteractor.swift

import Foundation

protocol SidebarInteractorInputProtocol: AnyObject {
    func loadBookmarks()
    func addRepository(name: String, path: String)
    func removeRepository(at index: Int)
    func moveRepository(from: Int, to: Int)
    func selectRepository(path: String)
    func cloneRepository(url: String, targetPath: String)
    func initRepository(at path: String)
    func checkout(branchName: String, in repoPath: String, stashLocalChanges: Bool)
}

protocol SidebarInteractorOutputProtocol: AnyObject {
    func didLoadBookmarks(_ bookmarks: [RepositoryBookmark], activePath: String?)
    func didCloneSuccess(name: String, path: String)
    func didInitSuccess(name: String, path: String)
    func didOperationError(_ error: Error)
}

class SidebarInteractor: SidebarInteractorInputProtocol {
    
    weak var presenter: SidebarInteractorOutputProtocol?
    
    func loadBookmarks() {
        let bookmarks = RepositoryStore.shared.getBookmarks()
        let activePath = RepositoryStore.shared.getActiveRepositoryPath()
        presenter?.didLoadBookmarks(bookmarks, activePath: activePath)
    }
    
    func addRepository(name: String, path: String) {
        RepositoryStore.shared.addBookmark(name: name, path: path)
        loadBookmarks()
    }
    
    func removeRepository(at index: Int) {
        RepositoryStore.shared.removeBookmark(at: index)
        loadBookmarks()
    }
    
    func moveRepository(from: Int, to: Int) {
        RepositoryStore.shared.moveBookmark(from: from, to: to)
        loadBookmarks()
    }
    
    func selectRepository(path: String) {
        RepositoryStore.shared.setActiveRepository(path: path)
        loadBookmarks()
    }
    
    func cloneRepository(url: String, targetPath: String) {
        Task {
            do {
                try await GitService.shared.clone(url: url, to: targetPath)
                let name = URL(fileURLWithPath: targetPath).lastPathComponent
                await MainActor.run {
                    self.addRepository(name: name, path: targetPath)
                    self.presenter?.didCloneSuccess(name: name, path: targetPath)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func initRepository(at path: String) {
        Task {
            do {
                try await GitService.shared.initRepository(at: path)
                let name = URL(fileURLWithPath: path).lastPathComponent
                await MainActor.run {
                    self.addRepository(name: name, path: path)
                    self.presenter?.didInitSuccess(name: name, path: path)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func checkout(branchName: String, in repoPath: String, stashLocalChanges: Bool) {
        Task {
            do {
                if stashLocalChanges {
                    try await GitService.shared.stashSave(message: "Stash before switching to \(branchName)", in: repoPath)
                }
                
                try await GitService.shared.checkout(branch: branchName, in: repoPath)
                await MainActor.run {
                    RepositoryStore.shared.setActiveRepository(path: repoPath)
                    self.loadBookmarks()
                    NotificationCenter.default.post(name: .repositoryContentShouldRefresh, object: nil)
                    NotificationCenter.default.post(name: .repositoryFilesChanged, object: nil)
                    NotificationCenter.default.post(name: .sidebarShouldRefreshStats, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
