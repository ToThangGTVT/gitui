import Foundation

protocol BlameInteractorProtocol: AnyObject {
    func fetchBlame(for filePath: String, at commitHash: String?, repoPath: String)
}

class BlameInteractor: BlameInteractorProtocol {
    weak var presenter: BlameInteractorOutputProtocol?
    
    func fetchBlame(for filePath: String, at commitHash: String?, repoPath: String) {
        guard !repoPath.isEmpty else { return }
        
        Task {
            do {
                let lines = try await GitBlameService.shared.getBlame(for: filePath, at: commitHash, in: repoPath)
                await MainActor.run {
                    presenter?.didLoadBlame(lines)
                }
            } catch {
                await MainActor.run {
                    presenter?.didFailToLoadBlame(error: error)
                }
            }
        }
    }
}
