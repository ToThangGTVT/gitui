// MARK: - ChangesInteractor.swift

import Foundation

protocol ChangesInteractorInputProtocol: AnyObject {
    func loadStatus(repoPath: String)
    func loadDiff(repoPath: String, file: GitFileStatus)
    func stageFile(repoPath: String, file: GitFileStatus)
    func unstageFile(repoPath: String, file: GitFileStatus)
    func stageAll(repoPath: String)
    func unstageAll(repoPath: String)
    func commit(repoPath: String, message: String)
    func discardFile(repoPath: String, file: GitFileStatus)
    func removeFile(repoPath: String, file: GitFileStatus)
    func ignoreFile(repoPath: String, file: GitFileStatus)
}

protocol ChangesInteractorOutputProtocol: AnyObject {
    func didLoadStatus(staged: [GitFileStatus], unstaged: [GitFileStatus])
    func didLoadDiff(text: String, file: String)
    func didOperationError(_ error: Error)
    func didCommitSuccessfully()
}

class ChangesInteractor: ChangesInteractorInputProtocol {
    
    weak var presenter: ChangesInteractorOutputProtocol?
    
    func loadStatus(repoPath: String) {
        Task {
            do {
                let status = try await GitService.shared.getStatus(in: repoPath)
                await MainActor.run {
                    self.presenter?.didLoadStatus(staged: status.staged, unstaged: status.unstaged)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func loadDiff(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                let diff = try await GitService.shared.getDiff(in: repoPath, file: file.path, staged: file.isStaged)
                await MainActor.run {
                    self.presenter?.didLoadDiff(text: diff, file: file.path)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func stageFile(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                try await GitService.shared.stageFile(file.path, in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func unstageFile(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                try await GitService.shared.unstageFile(file.path, in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func stageAll(repoPath: String) {
        Task {
            do {
                try await GitService.shared.stageAll(in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func unstageAll(repoPath: String) {
        Task {
            do {
                try await GitService.shared.unstageAll(in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func commit(repoPath: String, message: String) {
        Task {
            do {
                try await GitService.shared.commit(message: message, in: repoPath)
                await MainActor.run {
                    self.presenter?.didCommitSuccessfully()
                }
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func discardFile(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                if file.status == "?" {
                    // Untracked file: delete it
                    try GitService.shared.discardUntrackedFile(file.path, in: repoPath)
                } else {
                    // Tracked file: restore from HEAD
                    try await GitService.shared.discardFile(file.path, in: repoPath)
                }
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func removeFile(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                try await GitService.shared.removeFile(file.path, in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func ignoreFile(repoPath: String, file: GitFileStatus) {
        Task {
            do {
                try GitService.shared.addToGitignore(file.path, in: repoPath)
                self.loadStatus(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
