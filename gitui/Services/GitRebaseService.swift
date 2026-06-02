import Foundation

struct RebaseTodoItem: Identifiable, Equatable {
    var id: String { hash }
    let hash: String
    var action: RebaseAction
    let message: String
}

enum RebaseAction: String, CaseIterable {
    case pick = "pick"
    case reword = "reword"
    case edit = "edit"
    case squash = "squash"
    case fixup = "fixup"
    case drop = "drop"
}

protocol GitRebaseServiceProtocol: Sendable {
    func getCommitsForRebase(onto: String, in repoPath: String) async throws -> [RebaseTodoItem]
    func executeInteractiveRebase(onto: String, items: [RebaseTodoItem], in repoPath: String) async throws
    func abortRebase(in repoPath: String) async throws
    func continueRebase(in repoPath: String) async throws
}

final class GitRebaseService: GitRebaseServiceProtocol, @unchecked Sendable {
    static let shared = GitRebaseService()
    private init() {}
    
    func getCommitsForRebase(onto: String, in repoPath: String) async throws -> [RebaseTodoItem] {
        // Lấy danh sách commit từ `onto` đến HEAD
        let output = try await GitService.shared.runGit(["log", "--reverse", "--pretty=format:%h|%s", "\(onto)..HEAD"], in: repoPath)
        
        var items: [RebaseTodoItem] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }
            let hash = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let msg = parts[1...].joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !hash.isEmpty {
                items.append(RebaseTodoItem(hash: hash, action: .pick, message: msg))
            }
        }
        return items
    }
    
    func executeInteractiveRebase(onto: String, items: [RebaseTodoItem], in repoPath: String) async throws {
        // 1. Tạo file TODO tạm thời
        let todoContent = items.map { "\($0.action.rawValue) \($0.hash) \($0.message)" }.joined(separator: "\n")
        
        let tempDir = FileManager.default.temporaryDirectory
        let todoFileName = "git-rebase-todo-\(UUID().uuidString)"
        let todoFileURL = tempDir.appendingPathComponent(todoFileName)
        
        try todoContent.write(to: todoFileURL, atomically: true, encoding: .utf8)
        
        // 2. Chạy git rebase -i với GIT_SEQUENCE_EDITOR copy đè file TODO này
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
            
            // Script đơn giản để copy file todo của ta vào file todo của git
            // File todo của git được truyền vào arg $1 của editor script
            let scriptPath = todoFileURL.path
            process.arguments = ["git", "rebase", "-i", onto]
            
            var env = ProcessInfo.processInfo.environment
            env["GIT_SEQUENCE_EDITOR"] = "cp '\(scriptPath)'"
            process.environment = env
            
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            // Dọn dẹp
            try? FileManager.default.removeItem(at: todoFileURL)
            
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Rebase error"
                throw NSError(domain: "GitErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
        }.value
    }
    
    func abortRebase(in repoPath: String) async throws {
        _ = try await GitService.shared.runGit(["rebase", "--abort"], in: repoPath)
    }
    
    func continueRebase(in repoPath: String) async throws {
        // Việc continue sau khi giải quyết conflict cần GIT_EDITOR = cat (nếu không muốn mở vi)
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
            process.arguments = ["git", "rebase", "--continue"]
            
            var env = ProcessInfo.processInfo.environment
            env["GIT_EDITOR"] = "cat"
            process.environment = env
            
            let errPipe = Pipe()
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Rebase continue error"
                throw NSError(domain: "GitErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
        }.value
    }
}
