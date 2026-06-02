import Foundation

protocol InteractiveRebaseInteractorProtocol: AnyObject {
    func loadCommits(onto: String, repoPath: String)
    func executeRebase(onto: String, items: [RebaseTodoItem], repoPath: String)
}

protocol InteractiveRebaseInteractorOutputProtocol: AnyObject {
    func didLoadCommits(_ commits: [RebaseTodoItem])
    func didFailToLoadCommits(error: Error)
    func didExecuteRebaseSuccessfully()
    func didFailToExecuteRebase(error: Error)
}

class InteractiveRebaseInteractor: InteractiveRebaseInteractorProtocol {
    weak var presenter: InteractiveRebaseInteractorOutputProtocol?
    
    func loadCommits(onto: String, repoPath: String) {
        Task {
            do {
                let commits = try await GitRebaseService.shared.getCommitsForRebase(onto: onto, in: repoPath)
                await MainActor.run {
                    presenter?.didLoadCommits(commits)
                }
            } catch {
                await MainActor.run {
                    presenter?.didFailToLoadCommits(error: error)
                }
            }
        }
    }
    
    func executeRebase(onto: String, items: [RebaseTodoItem], repoPath: String) {
        Task {
            do {
                try await GitRebaseService.shared.executeInteractiveRebase(onto: onto, items: items, in: repoPath)
                await MainActor.run {
                    presenter?.didExecuteRebaseSuccessfully()
                }
            } catch {
                await MainActor.run {
                    presenter?.didFailToExecuteRebase(error: error)
                }
            }
        }
    }
}
