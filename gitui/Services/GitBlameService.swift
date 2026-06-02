import Foundation

struct GitBlameLine: Identifiable, Equatable {
    let id = UUID()
    let commitHash: String
    let author: String
    let date: String
    let lineNumber: Int
    let content: String
}

protocol GitBlameServiceProtocol: Sendable {
    func getBlame(for filePath: String, at commitHash: String?, in repoPath: String) async throws -> [GitBlameLine]
    func getFileHistory(for filePath: String, in repoPath: String) async throws -> [GitCommit]
}

final class GitBlameService: GitBlameServiceProtocol, @unchecked Sendable {
    static let shared = GitBlameService()
    private init() {}
    
    func getBlame(for filePath: String, at commitHash: String?, in repoPath: String) async throws -> [GitBlameLine] {
        var args = ["blame", "--line-porcelain"]
        if let hash = commitHash, !hash.isEmpty {
            args.append(hash)
        }
        args.append("--")
        args.append(filePath)
        
        let output = try await GitService.shared.runGit(args, in: repoPath)
        
        var blameLines: [GitBlameLine] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentHash = ""
        var currentAuthor = ""
        var currentDate = ""
        var currentLineNumber = 0
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.isEmpty {
                i += 1
                continue
            }
            
            // Porcelain format:
            // hash original_line final_line group_lines
            // author name
            // author-mail <email>
            // author-time time
            // ...
            // \tcontent
            
            if line.hasPrefix("\t") {
                // Content line
                let content = String(line.dropFirst())
                blameLines.append(GitBlameLine(
                    commitHash: currentHash,
                    author: currentAuthor,
                    date: currentDate,
                    lineNumber: currentLineNumber,
                    content: content
                ))
            } else if let spaceIndex = line.firstIndex(of: " ") {
                let prefix = String(line[..<spaceIndex])
                let value = String(line[line.index(after: spaceIndex)...])
                
                if prefix.count == 40 && line.components(separatedBy: " ").count >= 3 {
                    // This is the header line for a blame chunk: hash orig_ln final_ln [group_lines]
                    currentHash = String(prefix.prefix(8)) // short hash
                    let parts = line.components(separatedBy: " ")
                    if parts.count >= 3, let ln = Int(parts[2]) {
                        currentLineNumber = ln
                    }
                } else if prefix == "author" {
                    currentAuthor = value
                } else if prefix == "author-time" {
                    if let timeInt = TimeInterval(value) {
                        let date = Date(timeIntervalSince1970: timeInt)
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        currentDate = formatter.string(from: date)
                    }
                }
            }
            i += 1
        }
        
        return blameLines
    }
    
    func getFileHistory(for filePath: String, in repoPath: String) async throws -> [GitCommit] {
        // Format: hash|author|date|message
        let format = "%h|%an|%ad|%s"
        let output = try await GitService.shared.runGit(["log", "--pretty=format:\(format)", "--date=short", "--", filePath], in: repoPath)
        
        var commits: [GitCommit] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            let components = line.components(separatedBy: "|")
            if components.count >= 4 {
                commits.append(GitCommit(
                    hash: components[0],
                    shortHash: components[0],
                    author: components[1],
                    date: components[2],
                    message: components[3],
                    graphSymbol: "*",
                    graphLine: "*"
                ))
            }
        }
        return commits
    }
}
