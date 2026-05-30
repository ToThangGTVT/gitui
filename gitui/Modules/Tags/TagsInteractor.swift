// MARK: - TagsInteractor.swift

import Foundation

protocol TagsInteractorInputProtocol: AnyObject {
    func loadTags(repoPath: String)
    func createTag(repoPath: String, name: String)
    func deleteTag(repoPath: String, name: String)
    func pushTag(repoPath: String, name: String, remote: String)
}

protocol TagsInteractorOutputProtocol: AnyObject {
    func didLoadTags(_ tags: [GitTag])
    func didOperationSuccess(message: String)
    func didOperationError(_ error: Error)
}

class TagsInteractor: TagsInteractorInputProtocol {
    
    weak var presenter: TagsInteractorOutputProtocol?
    
    func loadTags(repoPath: String) {
        Task {
            do {
                let tags = try await GitService.shared.getTags(in: repoPath)
                await MainActor.run {
                    self.presenter?.didLoadTags(tags)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func createTag(repoPath: String, name: String) {
        Task {
            do {
                try await GitService.shared.createTag(name: name, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Tag '\(name)' created successfully.")
                }
                self.loadTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func deleteTag(repoPath: String, name: String) {
        Task {
            do {
                try await GitService.shared.deleteTag(name: name, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Tag '\(name)' deleted successfully.")
                }
                self.loadTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func pushTag(repoPath: String, name: String, remote: String) {
        Task {
            do {
                try await GitService.shared.pushTag(remote: remote, name: name, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully pushed tag '\(name)' to remote '\(remote)'.")
                }
                self.loadTags(repoPath: repoPath)
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
}
