import Foundation

struct GitSubmodule: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let url: String
    let hash: String
    let status: SubmoduleStatus
    
    enum SubmoduleStatus {
        case uninitialized
        case upToDate
        case modified
    }
}

protocol GitSubmoduleServiceProtocol: Sendable {
    func getSubmodules(in repoPath: String) async throws -> [GitSubmodule]
    func updateSubmodules(in repoPath: String) async throws
    func addSubmodule(url: String, path: String, in repoPath: String) async throws
}

final class GitSubmoduleService: GitSubmoduleServiceProtocol, @unchecked Sendable {
    static let shared = GitSubmoduleService()
    private init() {}
    
    func getSubmodules(in repoPath: String) async throws -> [GitSubmodule] {
        let output = try? await GitService.shared.runGit(["submodule", "status"], in: repoPath)
        guard let output = output, !output.isEmpty else { return [] }
        
        var submodules: [GitSubmodule] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            // Format: " {hash} {path} ({describe})" -> up to date
            // "+{hash} {path} ({describe})" -> modified
            // "-{hash} {path}" -> uninitialized
            
            let statusChar = line.first!
            let remainder = String(line.dropFirst())
            let parts = remainder.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if parts.count >= 2 {
                let hash = parts[0]
                let path = parts[1]
                
                let status: GitSubmodule.SubmoduleStatus
                switch statusChar {
                case "-": status = .uninitialized
                case "+": status = .modified
                default: status = .upToDate
                }
                
                // Get URL from config
                let urlOutput = try? await GitService.shared.runGit(["config", "--file", ".gitmodules", "--get", "submodule.\(path).url"], in: repoPath)
                let url = urlOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                submodules.append(GitSubmodule(path: path, url: url, hash: hash, status: status))
            }
        }
        
        return submodules
    }
    
    func updateSubmodules(in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["submodule", "update", "--init", "--recursive"], in: repoPath)
    }
    
    func addSubmodule(url: String, path: String, in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["submodule", "add", url, path], in: repoPath)
    }
}
