// MARK: - RemotesInteractor.swift

import Foundation

protocol RemotesInteractorInputProtocol: AnyObject {
    func loadRemotes(repoPath: String)
    func addRemote(repoPath: String, name: String, url: String)
    func removeRemote(repoPath: String, name: String)
    func fetchRemote(repoPath: String, name: String)
    func pullRemote(repoPath: String, name: String, branch: String)
    func pushRemote(repoPath: String, name: String, branch: String)
}

protocol RemotesInteractorOutputProtocol: AnyObject {
    func didLoadRemotes(_ remotes: [GitRemote])
    func didOperationSuccess(message: String)
    func didOperationError(_ error: Error)
}

class RemotesInteractor: RemotesInteractorInputProtocol {
    
    weak var presenter: RemotesInteractorOutputProtocol?
    
    func loadRemotes(repoPath: String) {
        Task {
            do {
                let remotes = try await GitService.shared.getRemotes(in: repoPath)
                await MainActor.run {
                    self.presenter?.didLoadRemotes(remotes)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func addRemote(repoPath: String, name: String, url: String) {
        Task {
            do {
                try await GitService.shared.addRemote(name: name, url: url, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Remote '\(name)' added successfully.")
                }
                self.loadRemotes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func removeRemote(repoPath: String, name: String) {
        Task {
            do {
                try await GitService.shared.removeRemote(name: name, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Remote '\(name)' removed successfully.")
                }
                self.loadRemotes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func fetchRemote(repoPath: String, name: String) {
        Task {
            do {
                try await GitService.shared.fetch(remote: name, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully fetched from remote '\(name)'.")
                }
                self.loadRemotes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func pullRemote(repoPath: String, name: String, branch: String) {
        Task {
            do {
                try await GitService.shared.pull(remote: name, branch: branch, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully pulled \(branch) from remote '\(name)'.")
                }
                self.loadRemotes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func pushRemote(repoPath: String, name: String, branch: String) {
        Task {
            do {
                try await GitService.shared.push(remote: name, branch: branch, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully pushed \(branch) to remote '\(name)'.")
                }
                self.loadRemotes(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
