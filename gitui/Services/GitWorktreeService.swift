import Foundation

struct GitWorktree: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let hash: String
    let branch: String // Can be branch name or detached HEAD
}

protocol GitWorktreeServiceProtocol: Sendable {
    func getWorktrees(in repoPath: String) async throws -> [GitWorktree]
    func addWorktree(path: String, branch: String, in repoPath: String) async throws
    func removeWorktree(path: String, in repoPath: String) async throws
}

final class GitWorktreeService: GitWorktreeServiceProtocol, @unchecked Sendable {
    static let shared = GitWorktreeService()
    private init() {}
    
    func getWorktrees(in repoPath: String) async throws -> [GitWorktree] {
        let output = try await GitService.shared.runGit(["worktree", "list", "--porcelain"], in: repoPath)
        var worktrees: [GitWorktree] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        var currentPath = ""
        var currentHash = ""
        var currentBranch = ""
        
        for line in lines {
            if line.isEmpty {
                // End of a worktree entry
                if !currentPath.isEmpty {
                    worktrees.append(GitWorktree(path: currentPath, hash: currentHash, branch: currentBranch))
                }
                currentPath = ""
                currentHash = ""
                currentBranch = ""
                continue
            }
            
            if line.hasPrefix("worktree ") {
                currentPath = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("HEAD ") {
                currentHash = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let fullBranch = String(line.dropFirst("branch ".count))
                // Format: refs/heads/branchName
                currentBranch = fullBranch.replacingOccurrences(of: "refs/heads/", with: "")
            } else if line == "detached" {
                currentBranch = "(detached)"
            }
        }
        
        // Push the last one if EOF doesn't end with blank line
        if !currentPath.isEmpty {
            worktrees.append(GitWorktree(path: currentPath, hash: currentHash, branch: currentBranch))
        }
        
        return worktrees
    }
    
    func addWorktree(path: String, branch: String, in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["worktree", "add", path, branch], in: repoPath)
    }
    
    func removeWorktree(path: String, in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["worktree", "remove", path, "--force"], in: repoPath)
    }
}
