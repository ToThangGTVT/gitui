import Foundation

struct ConflictChunk: Identifiable, Equatable {
    let id = UUID()
    let currentContent: String // between <<<<<<< and =======
    let incomingContent: String // between ======= and >>>>>>>
    let baseContent: String? // optional, if using diff3 style (|||||||)
    var resolvedContent: String? // nil if unresolved
    let incomingBranchName: String
    let currentBranchName: String
    
    var isResolved: Bool {
        return resolvedContent != nil
    }
}

enum ResolutionType {
    case current
    case incoming
    case both
    case custom(String)
}

protocol GitConflictServiceProtocol: Sendable {
    func parseConflictFile(filePath: String, in repoPath: String) throws -> [Any] // Array of Strings (normal text) and ConflictChunks
    func saveResolvedFile(filePath: String, chunks: [Any], in repoPath: String) throws
}

final class GitConflictService: GitConflictServiceProtocol, @unchecked Sendable {
    static let shared = GitConflictService()
    private init() {}
    
    // Returns an array containing both normal String text and ConflictChunk objects.
    func parseConflictFile(filePath: String, in repoPath: String) throws -> [Any] {
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        let fileContent = try String(contentsOfFile: fullPath, encoding: .utf8)
        
        var elements: [Any] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        var currentNormalText = ""
        var inConflict = false
        
        var currentChunkContent = ""
        var incomingChunkContent = ""
        var baseChunkContent = ""
        
        var currentBranchName = ""
        var incomingBranchName = ""
        
        enum ConflictState {
            case none, current, base, incoming
        }
        var state: ConflictState = .none
        
        for line in lines {
            if line.hasPrefix("<<<<<<< ") {
                if !currentNormalText.isEmpty {
                    elements.append(currentNormalText)
                    currentNormalText = ""
                }
                inConflict = true
                state = .current
                currentBranchName = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                continue
            }
            
            if inConflict {
                if line.hasPrefix("||||||| ") {
                    state = .base
                    continue
                } else if line == "=======" {
                    state = .incoming
                    continue
                } else if line.hasPrefix(">>>>>>> ") {
                    incomingBranchName = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    
                    let chunk = ConflictChunk(
                        currentContent: currentChunkContent,
                        incomingContent: incomingChunkContent,
                        baseContent: baseChunkContent.isEmpty ? nil : baseChunkContent,
                        resolvedContent: nil,
                        incomingBranchName: incomingBranchName,
                        currentBranchName: currentBranchName
                    )
                    elements.append(chunk)
                    
                    // Reset
                    inConflict = false
                    state = .none
                    currentChunkContent = ""
                    incomingChunkContent = ""
                    baseChunkContent = ""
                    continue
                }
                
                switch state {
                case .current:
                    currentChunkContent += line + "\n"
                case .base:
                    baseChunkContent += line + "\n"
                case .incoming:
                    incomingChunkContent += line + "\n"
                case .none:
                    break
                }
            } else {
                currentNormalText += line + "\n"
            }
        }
        
        if !currentNormalText.isEmpty {
            // Remove the trailing newline if it's EOF
            if currentNormalText.hasSuffix("\n") {
                currentNormalText.removeLast()
            }
            elements.append(currentNormalText)
        }
        
        return elements
    }
    
    func saveResolvedFile(filePath: String, chunks: [Any], in repoPath: String) throws {
        var finalContent = ""
        for element in chunks {
            if let text = element as? String {
                finalContent += text
            } else if let chunk = element as? ConflictChunk {
                if let resolved = chunk.resolvedContent {
                    finalContent += resolved
                } else {
                    // Fallback to writing conflict markers if not resolved (should usually be prevented by UI)
                    finalContent += "<<<<<<< \(chunk.currentBranchName)\n"
                    finalContent += chunk.currentContent
                    if let base = chunk.baseContent {
                        finalContent += "|||||||\n\(base)"
                    }
                    finalContent += "=======\n"
                    finalContent += chunk.incomingContent
                    finalContent += ">>>>>>> \(chunk.incomingBranchName)\n"
                }
            }
        }
        
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        try finalContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }
}
