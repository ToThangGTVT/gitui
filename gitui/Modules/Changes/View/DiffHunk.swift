// MARK: - DiffHunk.swift

import Foundation

struct DiffHunk {
    let header: String
    let body: [String]
    let fileHeaders: [String]
    let startLineInText: Int
    let endLineInText: Int

    var patch: String {
        let allLines = fileHeaders + [header] + body
        return allLines.joined(separator: "\n") + "\n"
    }
}

func parseDiffHunks(from diffText: String) -> [DiffHunk] {
    let lines = diffText.components(separatedBy: "\n")
    var fileHeaders: [String] = []
    var hunks: [DiffHunk] = []
    var currentHunkHeader: String? = nil
    var currentHunkBody: [String] = []
    var currentHunkStart = 0

    func finishHunk(endLine: Int) {
        guard let header = currentHunkHeader else { return }
        hunks.append(DiffHunk(
            header: header,
            body: currentHunkBody,
            fileHeaders: fileHeaders,
            startLineInText: currentHunkStart,
            endLineInText: endLine
        ))
        currentHunkHeader = nil
        currentHunkBody = []
    }

    for (idx, line) in lines.enumerated() {
        if line.hasPrefix("diff --git") || line.hasPrefix("index ")
            || line.hasPrefix("--- ") || line.hasPrefix("+++ ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file")
            || line.hasPrefix("old mode") || line.hasPrefix("new mode") {
            finishHunk(endLine: idx - 1)
            fileHeaders.append(line)
        } else if line.hasPrefix("@@") {
            finishHunk(endLine: idx - 1)
            currentHunkHeader = line
            currentHunkStart = idx
        } else if currentHunkHeader != nil {
            currentHunkBody.append(line)
        }
    }

    finishHunk(endLine: max(lines.count - 1, currentHunkStart))
    return hunks
}
