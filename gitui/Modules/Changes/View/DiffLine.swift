// MARK: - DiffLine.swift

import Foundation

struct DiffLine {
    enum Kind {
        case fileHeader
        case hunkHeader(hunk: DiffHunk)
        case context(oldLine: Int, newLine: Int)
        case added(newLine: Int)
        case removed(oldLine: Int)
    }

    let kind: Kind
    let rawText: String
}

func buildDiffLines(from diffText: String, hunks: [DiffHunk]) -> [DiffLine] {
    let rawLines = diffText.components(separatedBy: "\n")
    let hunkByStart = Dictionary(uniqueKeysWithValues: hunks.map { ($0.startLineInText, $0) })

    var result: [DiffLine] = []
    var oldLine = 0
    var newLine = 0

    for (idx, raw) in rawLines.enumerated() {
        // Skip the final trailing empty line produced by the last "\n"
        if idx == rawLines.count - 1 && raw.isEmpty { continue }

        if let hunk = hunkByStart[idx] {
            // Parse starting line numbers from @@ -oldStart[,count] +newStart[,count] @@
            let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
            if let match = raw.range(of: pattern, options: .regularExpression) {
                let nums = String(raw[match])
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .filter { !$0.isEmpty }
                if nums.count >= 2 {
                    oldLine = Int(nums[0]) ?? 1
                    newLine = Int(nums[1]) ?? 1
                }
            }
            result.append(DiffLine(kind: .hunkHeader(hunk: hunk), rawText: raw))

        } else if raw.hasPrefix("diff --git") || raw.hasPrefix("index ")
               || raw.hasPrefix("--- ") || raw.hasPrefix("+++ ")
               || raw.hasPrefix("new file") || raw.hasPrefix("deleted file")
               || raw.hasPrefix("old mode") || raw.hasPrefix("new mode")
               || raw.hasPrefix("Similarity index") {
            // Do not append file headers to make the UI cleaner for normal users
            continue

        } else if raw.hasPrefix("+") {
            result.append(DiffLine(kind: .added(newLine: newLine), rawText: raw))
            newLine += 1

        } else if raw.hasPrefix("-") {
            result.append(DiffLine(kind: .removed(oldLine: oldLine), rawText: raw))
            oldLine += 1

        } else {
            result.append(DiffLine(kind: .context(oldLine: oldLine, newLine: newLine), rawText: raw))
            oldLine += 1
            newLine += 1
        }
    }

    return result
}
