// MARK: - BranchesInteractor.swift

import Foundation

protocol BranchesInteractorInputProtocol: AnyObject {
    func loadBranchesAndTags(repoPath: String)
    func checkout(repoPath: String, branchName: String)
    func merge(repoPath: String, branchName: String)
    func deleteBranch(repoPath: String, branchName: String, force: Bool)
    func renameBranch(repoPath: String, oldName: String, newName: String)
    func pushBranch(repoPath: String, branchName: String)
}

protocol BranchesInteractorOutputProtocol: AnyObject {
    func didLoadBranchesAndTags(branches: [GitBranch], tags: [GitTag])
    func didOperationSuccess(message: String)
    func didOperationError(_ error: Error)
}

class BranchesInteractor: BranchesInteractorInputProtocol {
    
    weak var presenter: BranchesInteractorOutputProtocol?
    
    func loadBranchesAndTags(repoPath: String) {
        Task {
            do {
                let branches = try await GitService.shared.getBranches(in: repoPath)
                let tags = try await GitService.shared.getTags(in: repoPath)
                await MainActor.run {
                    self.presenter?.didLoadBranchesAndTags(branches: branches, tags: tags)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func checkout(repoPath: String, branchName: String) {
        Task {
            do {
                try await GitService.shared.checkout(branch: branchName, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully checked out \(branchName)")
                }
                self.loadBranchesAndTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func merge(repoPath: String, branchName: String) {
        Task {
            do {
                try await GitService.shared.merge(branch: branchName, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully merged \(branchName) into current branch.")
                }
                self.loadBranchesAndTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func deleteBranch(repoPath: String, branchName: String, force: Bool) {
        Task {
            do {
                let arg = force ? "-D" : "-d"
                _ = try await GitService.shared.runGit(["branch", arg, branchName], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully deleted branch \(branchName)")
                }
                self.loadBranchesAndTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func renameBranch(repoPath: String, oldName: String, newName: String) {
        Task {
            do {
                _ = try await GitService.shared.runGit(["branch", "-m", oldName, newName], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully renamed \(oldName) to \(newName)")
                }
                self.loadBranchesAndTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func pushBranch(repoPath: String, branchName: String) {
        Task {
            do {
                _ = try await GitService.shared.runGit(["push", "origin", branchName], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully pushed branch \(branchName) to origin.")
                }
                self.loadBranchesAndTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
