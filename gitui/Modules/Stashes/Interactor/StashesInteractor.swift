// MARK: - StashesInteractor.swift

import Foundation

protocol StashesInteractorInputProtocol: AnyObject {
    func loadStashes(repoPath: String)
    func saveStash(repoPath: String, message: String)
    func applyStash(repoPath: String, index: Int)
    func popStash(repoPath: String, index: Int)
    func dropStash(repoPath: String, index: Int)
}

protocol StashesInteractorOutputProtocol: AnyObject {
    func didLoadStashes(_ stashes: [GitStash])
    func didOperationSuccess(message: String)
    func didOperationError(_ error: Error)
}

class StashesInteractor: StashesInteractorInputProtocol {
    
    weak var presenter: StashesInteractorOutputProtocol?
    
    func loadStashes(repoPath: String) {
        Task {
            do {
                let stashes = try await GitService.shared.getStashes(in: repoPath)
                await MainActor.run {
                    self.presenter?.didLoadStashes(stashes)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func saveStash(repoPath: String, message: String) {
        Task {
            do {
                try await GitService.shared.stashSave(message: message, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Stash created successfully.")
                }
                self.loadStashes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func applyStash(repoPath: String, index: Int) {
        Task {
            do {
                try await GitService.shared.stashApply(index: index, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Stash applied successfully.")
                }
                self.loadStashes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func popStash(repoPath: String, index: Int) {
        Task {
            do {
                try await GitService.shared.stashPop(index: index, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Stash popped successfully.")
                }
                self.loadStashes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func dropStash(repoPath: String, index: Int) {
        Task {
            do {
                try await GitService.shared.stashDrop(index: index, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Stash dropped successfully.")
                }
                self.loadStashes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
