import Foundation

protocol GitUndoServiceProtocol: Sendable {
    func undoLastCommit(in repoPath: String) async throws
    func canUndoCommit(in repoPath: String) async -> Bool
}

final class GitUndoService: GitUndoServiceProtocol, @unchecked Sendable {
    static let shared = GitUndoService()
    private init() {}
    
    // Check if there are any commits to undo
    func canUndoCommit(in repoPath: String) async -> Bool {
        do {
            let output = try await GitService.shared.runGit(["rev-list", "--count", "HEAD"], in: repoPath)
            if let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)), count > 0 {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // Performs git reset --soft HEAD~1
    func undoLastCommit(in repoPath: String) async throws {
        let canUndo = await canUndoCommit(in: repoPath)
        guard canUndo else {
            throw NSError(domain: "GitUndoErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "No commits to undo."])
        }
        
        _ = try await GitService.shared.runGit(["reset", "--soft", "HEAD~1"], in: repoPath)
    }
}
