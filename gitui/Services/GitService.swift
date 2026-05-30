// MARK: - GitService.swift

import Foundation

// MARK: - Entities

struct GitFileStatus: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let status: String
    let isStaged: Bool
    
    var statusDescription: String {
        switch status {
        case "A": return "Added"
        case "M": return "Modified"
        case "D": return "Deleted"
        case "R": return "Renamed"
        case "?", "U": return "Untracked"
        default: return "Modified"
        }
    }
}

struct GitCommit: Identifiable, Equatable {
    var id: String { hash }
    let hash: String
    let shortHash: String
    let author: String
    let date: String
    let message: String
    let graphSymbol: String
    let graphLine: String
}

struct GitBranch: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
    
    var shortName: String {
        if isRemote {
            return name.replacingOccurrences(of: "remotes/", with: "")
        }
        return name
    }
}

struct GitStash: Identifiable, Equatable {
    var id: String { "\(index)-\(hash)" }
    let index: Int
    let hash: String
    let name: String
    let message: String
}

struct GitRemote: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let url: String
}

struct GitTag: Identifiable, Equatable {
    var id: String { name }
    let name: String
}

// MARK: - GitService

class GitService {
    static let shared = GitService()
    
    private init() {}
    
    // Resolve the git executable path
    private func resolveGitPath() -> String {
        let paths = ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"]
        let fm = FileManager.default
        for path in paths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/usr/bin/git" // Default fallback
    }
    
    // Execute a git command asynchronously in the background
    func runGit(_ args: [String], in repoPath: String) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.resolveGitPath())
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
            
            // Set standard output and standard error pipes
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            
            let outString = String(data: outData, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                let errString = String(data: errData, encoding: .utf8) ?? "Unknown Git error"
                let cleanErrString = errString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanErrString.isEmpty {
                    throw NSError(domain: "GitErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: cleanErrString])
                }
            }
            
            return outString
        }.value
    }
    
    // Execute a git command and stream output in real-time
    func runGitStreaming(_ args: [String], in repoPath: String, onOutput: @escaping (String) -> Void) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.resolveGitPath())
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
            
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            
            var fullOutput = ""
            let outputQueue = DispatchQueue(label: "git.stream.output")
            let readQueue = DispatchQueue(label: "git.read.queue", attributes: .concurrent)
            
            readQueue.async {
                let fileHandle = outPipe.fileHandleForReading
                while true {
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { break }
                    if let str = String(data: data, encoding: .utf8) {
                        outputQueue.async {
                            fullOutput += str
                            DispatchQueue.main.async {
                                onOutput(str)
                            }
                        }
                    }
                }
            }
            
            readQueue.async {
                let fileHandle = errPipe.fileHandleForReading
                while true {
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { break }
                    if let str = String(data: data, encoding: .utf8) {
                        outputQueue.async {
                            fullOutput += str
                            DispatchQueue.main.async {
                                onOutput(str)
                            }
                        }
                    }
                }
            }
            
            try process.run()
            process.waitUntilExit()
            
            // Give readers a brief moment to complete writing any remaining buffered data
            Thread.sleep(forTimeInterval: 0.05)
            
            var finalOutput = ""
            outputQueue.sync {
                finalOutput = fullOutput
            }
            
            if process.terminationStatus != 0 {
                let cleanErr = finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                let errMsg = cleanErr.isEmpty ? "Unknown Git error (exit code \(process.terminationStatus))" : cleanErr
                throw NSError(domain: "GitErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
            
            return finalOutput
        }.value
    }
    
    // MARK: - Wrappers & Parsers
    
    func getStatus(in repoPath: String) async throws -> (staged: [GitFileStatus], unstaged: [GitFileStatus]) {
        let output = try await runGit(["status", "--porcelain=v1"], in: repoPath)
        var staged: [GitFileStatus] = []
        var unstaged: [GitFileStatus] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard line.count >= 4 else { continue }
            
            let xIndex = line.index(line.startIndex, offsetBy: 0)
            let yIndex = line.index(line.startIndex, offsetBy: 1)
            let x = String(line[xIndex])
            let y = String(line[yIndex])
            
            // Parse filename (it might be quoted or contain renamed arrows like "a -> b")
            let pathPart = String(line[line.index(line.startIndex, offsetBy: 3)...]).trimmingCharacters(in: .whitespaces)
            let cleanPath = pathPart.replacingOccurrences(of: "\"", with: "")
            
            // Staged status
            if x != " " && x != "?" {
                staged.append(GitFileStatus(path: cleanPath, status: x, isStaged: true))
            }
            // Unstaged status
            if y != " " || x == "?" {
                let statusChar = x == "?" ? "?" : y
                unstaged.append(GitFileStatus(path: cleanPath, status: statusChar, isStaged: false))
            }
        }
        return (staged, unstaged)
    }
    
    func getDiff(in repoPath: String, file: String, staged: Bool) async throws -> String {
        var args = ["diff"]
        if staged {
            args.append("--staged")
        }
        args.append("--")
        args.append(file)
        return try await runGit(args, in: repoPath)
    }
    
    func stageFile(_ path: String, in repoPath: String) async throws {
        _ = try await runGit(["add", path], in: repoPath)
    }
    
    func stageAll(in repoPath: String) async throws {
        _ = try await runGit(["add", "-A"], in: repoPath)
    }
    
    func unstageFile(_ path: String, in repoPath: String) async throws {
        _ = try await runGit(["reset", "HEAD", "--", path], in: repoPath)
    }
    
    func unstageAll(in repoPath: String) async throws {
        _ = try await runGit(["reset", "HEAD"], in: repoPath)
    }
    
    func commit(message: String, in repoPath: String) async throws {
        _ = try await runGit(["commit", "-m", message], in: repoPath)
    }
    
    func getHistory(in repoPath: String, limit: Int = 150) async throws -> [GitCommit] {
        // Pretty format: hash|author|date|message
        let format = "%h|%an|%ad|%s"
        let output = try await runGit(["log", "--graph", "--pretty=format:\(format)", "--date=short", "--all", "-n", "\(limit)"], in: repoPath)
        
        var commits: [GitCommit] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            // Check if the line has commit details split by |
            if let separatorIndex = line.range(of: "|")?.lowerBound {
                let graphPart = String(line[..<separatorIndex])
                let commitPart = String(line[line.index(after: separatorIndex)...])
                
                let commitComponents = commitPart.components(separatedBy: "|")
                if commitComponents.count >= 4 {
                    let shortHash = commitComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let author = commitComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let date = commitComponents[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let message = commitComponents[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let graphSymbol = graphPart.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    commits.append(GitCommit(
                        hash: shortHash, // Since --oneline or %h gives short, we'll expand it or use it as is
                        shortHash: shortHash,
                        author: author,
                        date: date,
                        message: message,
                        graphSymbol: graphSymbol.isEmpty ? "*" : graphSymbol,
                        graphLine: graphPart
                    ))
                } else {
                    // Line is just a graph segment with no commit (e.g. junction lines)
                    commits.append(GitCommit(
                        hash: UUID().uuidString,
                        shortHash: "",
                        author: "",
                        date: "",
                        message: line.trimmingCharacters(in: .whitespacesAndNewlines),
                        graphSymbol: "",
                        graphLine: line
                    ))
                }
            } else {
                // Standalone line
                commits.append(GitCommit(
                    hash: UUID().uuidString,
                    shortHash: "",
                    author: "",
                    date: "",
                    message: line.trimmingCharacters(in: .whitespacesAndNewlines),
                    graphSymbol: "",
                    graphLine: line
                ))
            }
        }
        return commits
    }
    
    func getBranches(in repoPath: String) async throws -> [GitBranch] {
        let output = try await runGit(["branch", "-a"], in: repoPath)
        var branches: [GitBranch] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let isCurrent = line.hasPrefix("*")
            let name = trimmed.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isRemote = name.hasPrefix("remotes/")
            
            // Filter out HEAD references
            guard !name.contains("->") else { continue }
            
            branches.append(GitBranch(name: name, isCurrent: isCurrent, isRemote: isRemote))
        }
        return branches
    }
    
    func checkout(branch: String, in repoPath: String) async throws {
        // If remote, create a tracking branch locally
        if branch.hasPrefix("remotes/") {
            let shortName = branch.components(separatedBy: "/").last ?? branch
            _ = try await runGit(["checkout", "-b", shortName, "--track", branch], in: repoPath)
        } else {
            _ = try await runGit(["checkout", branch], in: repoPath)
        }
    }
    
    func createBranch(name: String, startPoint: String, checkout: Bool, in repoPath: String) async throws {
        if checkout {
            _ = try await runGit(["checkout", "-b", name, startPoint], in: repoPath)
        } else {
            _ = try await runGit(["branch", name, startPoint], in: repoPath)
        }
    }
    
    /// Returns (ahead, behind) commit counts relative to upstream.
    /// ahead = commits to push, behind = commits to pull.
    func getAheadBehind(in repoPath: String) async -> (ahead: Int, behind: Int) {
        do {
            let output = try await runGit(["rev-list", "--count", "--left-right", "HEAD...@{upstream}"], in: repoPath)
            let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
            guard parts.count == 2,
                  let ahead = Int(parts[0]),
                  let behind = Int(parts[1]) else {
                return (0, 0)
            }
            return (ahead, behind)
        } catch {
            // No upstream configured or other error
            return (0, 0)
        }
    }
    
    func discardFile(_ filePath: String, in repoPath: String) async throws {
        _ = try await runGit(["checkout", "--", filePath], in: repoPath)
    }
    
    func discardUntrackedFile(_ filePath: String, in repoPath: String) throws {
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        try FileManager.default.removeItem(atPath: fullPath)
    }
    
    func removeFile(_ filePath: String, in repoPath: String) async throws {
        _ = try await runGit(["rm", "-f", filePath], in: repoPath)
    }
    
    func addToGitignore(_ filePath: String, in repoPath: String) throws {
        let gitignorePath = (repoPath as NSString).appendingPathComponent(".gitignore")
        let entry = filePath + "\n"
        if FileManager.default.fileExists(atPath: gitignorePath) {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: gitignorePath))
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            try entry.write(toFile: gitignorePath, atomically: true, encoding: .utf8)
        }
    }
    
    func merge(branch: String, in repoPath: String) async throws {
        _ = try await runGit(["merge", branch], in: repoPath)
    }
    
    func getStashes(in repoPath: String) async throws -> [GitStash] {
        let output = try await runGit(["stash", "list"], in: repoPath)
        var stashes: [GitStash] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Format: stash@{0}: WIP on master: 1c2d3e4 Commit msg
            if let colonIndex1 = trimmed.range(of: ":")?.lowerBound {
                let stashIdStr = String(trimmed[..<colonIndex1]) // stash@{0}
                let remainder = String(trimmed[trimmed.index(after: colonIndex1)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let indexStr = stashIdStr.replacingOccurrences(of: "stash@{", with: "").replacingOccurrences(of: "}", with: "")
                guard let index = Int(indexStr) else { continue }
                
                var commitHash = ""
                var commitMessage = remainder
                
                if let colonIndex2 = remainder.range(of: ":")?.lowerBound {
                    let branchInfo = String(remainder[..<colonIndex2])
                    let commitInfo = String(remainder[remainder.index(after: colonIndex2)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let commitComponents = commitInfo.components(separatedBy: " ")
                    if let firstComp = commitComponents.first, firstComp.count >= 7 {
                        commitHash = firstComp
                        commitMessage = commitInfo.replacingOccurrences(of: firstComp, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                stashes.append(GitStash(
                    index: index,
                    hash: commitHash,
                    name: stashIdStr,
                    message: commitMessage
                ))
            }
        }
        return stashes
    }
    
    func stashSave(message: String?, in repoPath: String) async throws {
        var args = ["stash", "push"]
        if let msg = message, !msg.isEmpty {
            args.append("-m")
            args.append(msg)
        }
        _ = try await runGit(args, in: repoPath)
    }
    
    func stashApply(index: Int, in repoPath: String) async throws {
        _ = try await runGit(["stash", "apply", "stash@{\(index)}"], in: repoPath)
    }
    
    func stashPop(index: Int, in repoPath: String) async throws {
        _ = try await runGit(["stash", "pop", "stash@{\(index)}"], in: repoPath)
    }
    
    func stashDrop(index: Int, in repoPath: String) async throws {
        _ = try await runGit(["stash", "drop", "stash@{\(index)}"], in: repoPath)
    }
    
    func getRemotes(in repoPath: String) async throws -> [GitRemote] {
        let output = try await runGit(["remote", "-v"], in: repoPath)
        var remotes: [GitRemote] = []
        var seenNames = Set<String>()
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let comps = trimmed.components(separatedBy: .whitespaces)
            let cleanComps = comps.filter { !$0.isEmpty }
            
            if cleanComps.count >= 2 {
                let name = cleanComps[0]
                let url = cleanComps[1]
                
                if !seenNames.contains(name) {
                    seenNames.insert(name)
                    remotes.append(GitRemote(name: name, url: url))
                }
            }
        }
        return remotes
    }
    
    func addRemote(name: String, url: String, in repoPath: String) async throws {
        _ = try await runGit(["remote", "add", name, url], in: repoPath)
    }
    
    func removeRemote(name: String, in repoPath: String) async throws {
        _ = try await runGit(["remote", "remove", name], in: repoPath)
    }
    
    func getLineStats(in repoPath: String) async throws -> (added: Int, removed: Int) {
        // Get stats for both staged and unstaged changes
        let unstagedOutput = try await runGit(["diff", "--numstat"], in: repoPath)
        let stagedOutput = try await runGit(["diff", "--numstat", "--staged"], in: repoPath)
        
        var totalAdded = 0
        var totalRemoved = 0
        
        for line in (unstagedOutput + "\n" + stagedOutput).components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            // Binary files show "-" instead of numbers
            if let added = Int(parts[0]) { totalAdded += added }
            if let removed = Int(parts[1]) { totalRemoved += removed }
        }
        
        return (totalAdded, totalRemoved)
    }
    
    func fetch(remote: String, in repoPath: String) async throws {
        _ = try await runGit(["fetch", remote], in: repoPath)
    }
    
    func pull(remote: String, branch: String, in repoPath: String) async throws {
        _ = try await runGit(["pull", remote, branch], in: repoPath)
    }
    
    func push(remote: String, branch: String, in repoPath: String) async throws {
        _ = try await runGit(["push", remote, branch], in: repoPath)
    }
    
    @discardableResult
    func pushStreaming(remote: String, branch: String, in repoPath: String, onOutput: @escaping (String) -> Void) async throws -> String {
        return try await runGitStreaming(["push", remote, branch], in: repoPath, onOutput: onOutput)
    }
    
    func getTags(in repoPath: String) async throws -> [GitTag] {
        let output = try await runGit(["tag"], in: repoPath)
        var tags: [GitTag] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            tags.append(GitTag(name: trimmed))
        }
        return tags
    }
    
    func createTag(name: String, in repoPath: String) async throws {
        _ = try await runGit(["tag", name], in: repoPath)
    }
    
    func deleteTag(name: String, in repoPath: String) async throws {
        _ = try await runGit(["tag", "-d", name], in: repoPath)
    }
    
    func pushTag(remote: String, name: String, in repoPath: String) async throws {
        _ = try await runGit(["push", remote, name], in: repoPath)
    }
    
    func cherryPick(hash: String, in repoPath: String) async throws {
        _ = try await runGit(["cherry-pick", hash], in: repoPath)
    }
    
    func revert(hash: String, in repoPath: String) async throws {
        _ = try await runGit(["revert", "--no-edit", hash], in: repoPath)
    }
    
    func clone(url: String, to path: String) async throws {
        // Clone is run outside a specific repo folder, we use `/` or empty parent folder
        _ = try await runGit(["clone", url, path], in: "/")
    }
    
    func initRepository(at path: String) async throws {
        _ = try await runGit(["init"], in: path)
    }
}
