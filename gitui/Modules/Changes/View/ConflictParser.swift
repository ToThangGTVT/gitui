// MARK: - ConflictParser.swift

import Foundation

enum ConflictChunk: Equatable {
    case text(content: String)
    case conflict(current: String, incoming: String, currentLabel: String, incomingLabel: String)
}

class ConflictParser {
    static func parse(content: String) -> [ConflictChunk] {
        var chunks: [ConflictChunk] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentLines: [String] = []
        var incomingLines: [String] = []
        var currentLabel = ""
        var incomingLabel = ""
        var textLines: [String] = []
        
        // states for conflict
        // 0: outside conflict
        // 1: reading current (after <<<<<<<)
        // 2: reading incoming (after =======)
        var state = 0
        
        for line in lines {
            if line.hasPrefix("<<<<<<< ") {
                if !textLines.isEmpty {
                    chunks.append(.text(content: textLines.joined(separator: "\n")))
                    textLines.removeAll()
                }
                state = 1
                currentLabel = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                currentLines.removeAll()
                incomingLines.removeAll()
            } else if line.hasPrefix("=======") && state == 1 {
                state = 2
            } else if line.hasPrefix(">>>>>>> ") && state == 2 {
                incomingLabel = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                
                let curStr = currentLines.joined(separator: "\n")
                let incStr = incomingLines.joined(separator: "\n")
                chunks.append(.conflict(current: curStr, incoming: incStr, currentLabel: currentLabel, incomingLabel: incomingLabel))
                
                state = 0
                currentLabel = ""
                incomingLabel = ""
                currentLines.removeAll()
                incomingLines.removeAll()
            } else {
                if state == 0 {
                    textLines.append(line)
                } else if state == 1 {
                    currentLines.append(line)
                } else if state == 2 {
                    incomingLines.append(line)
                }
            }
        }
        
        if !textLines.isEmpty {
            chunks.append(.text(content: textLines.joined(separator: "\n")))
        }
        
        // If file ended while in conflict (malformed), dump remaining as text
        if state != 0 {
            var malformed = ""
            if state == 1 {
                malformed = "<<<<<<< \(currentLabel)\n" + currentLines.joined(separator: "\n")
            } else if state == 2 {
                malformed = "<<<<<<< \(currentLabel)\n" + currentLines.joined(separator: "\n") + "\n=======\n" + incomingLines.joined(separator: "\n")
            }
            chunks.append(.text(content: malformed))
        }
        
        return chunks
    }
    
    static func serialize(chunks: [ConflictChunk]) -> String {
        var lines: [String] = []
        for chunk in chunks {
            switch chunk {
            case .text(let content):
                lines.append(content)
            case .conflict(let current, let incoming, let curLbl, let incLbl):
                lines.append("<<<<<<< \(curLbl)")
                if !current.isEmpty { lines.append(current) }
                lines.append("=======")
                if !incoming.isEmpty { lines.append(incoming) }
                lines.append(">>>>>>> \(incLbl)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
