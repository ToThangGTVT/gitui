import Foundation

enum GitSearchFilterType: String {
    case message = "--grep"
    case author = "--author"
}

protocol GitSearchServiceProtocol: Sendable {
    func searchCommits(query: String, filterType: GitSearchFilterType, in repoPath: String) async throws -> [GitCommit]
}

final class GitSearchService: GitSearchServiceProtocol, @unchecked Sendable {
    static let shared = GitSearchService()
    private init() {}
    
    func searchCommits(query: String, filterType: GitSearchFilterType, in repoPath: String) async throws -> [GitCommit] {
        let format = "%h|%an|%ad|%s"
        var args = ["log", "--pretty=format:\(format)", "--date=short", "--all", "-i"]
        args.append("\(filterType.rawValue)=\(query)")
        
        let output = try await GitService.shared.runGit(args, in: repoPath)
        
        var commits: [GitCommit] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            let components = line.components(separatedBy: "|")
            if components.count >= 4 {
                commits.append(GitCommit(
                    hash: components[0].trimmingCharacters(in: .whitespacesAndNewlines),
                    shortHash: components[0].trimmingCharacters(in: .whitespacesAndNewlines),
                    author: components[1].trimmingCharacters(in: .whitespacesAndNewlines),
                    date: components[2].trimmingCharacters(in: .whitespacesAndNewlines),
                    message: components[3...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines),
                    graphSymbol: "*",
                    graphLine: "*"
                ))
            }
        }
        return commits
    }
}
