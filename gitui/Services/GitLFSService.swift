import Foundation

protocol GitLFSServiceProtocol: Sendable {
    func isLFSInstalled(in repoPath: String) async -> Bool
    func trackFile(pattern: String, in repoPath: String) async throws
    func pullLFSFiles(in repoPath: String) async throws
}

final class GitLFSService: GitLFSServiceProtocol, @unchecked Sendable {
    static let shared = GitLFSService()
    private init() {}
    
    func isLFSInstalled(in repoPath: String) async -> Bool {
        let output = try? await GitService.shared.runGit(["lfs", "version"], in: repoPath)
        return output?.contains("git-lfs") == true
    }
    
    func trackFile(pattern: String, in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["lfs", "track", pattern], in: repoPath)
        // Also need to add .gitattributes to git
        _ = try await GitService.shared.runGit(["add", ".gitattributes"], in: repoPath)
    }
    
    func pullLFSFiles(in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["lfs", "pull"], in: repoPath)
    }
}
