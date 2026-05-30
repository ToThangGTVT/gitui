// MARK: - HistoryEntity.swift

import Cocoa

struct CommitNode: Equatable {
    let hash: String          // full SHA-1
    let shortHash: String     // first 7 chars
    let message: String
    let author: String
    let date: Date
    let parents: [String]     // parent hashes (merge = 2)
    let refs: [GitRef]        // branch/tag labels on this commit
    var laneIndex: Int        // which column this dot sits on
    var edges: [GraphEdge]    // lines to draw from this row
}

struct BranchLane: Equatable {
    let index: Int
    let color: NSColor        // one of the 8 rotating colors
}

struct GraphEdge: Equatable {
    let fromLane: Int
    let toLane: Int
    let type: EdgeType       // straight | mergeIn | mergeOut | fork
}

enum EdgeType: Equatable {
    case straight
    case mergeIn
    case mergeOut
    case fork
}

enum GitRef: Equatable {
    case localBranch(String)
    case remoteBranch(String)
    case tag(String)
    case head
}

enum CommitAction {
    case checkout(hash: String)
    case createBranch(hash: String, name: String)
    case createTag(hash: String, name: String, message: String)
    case cherryPick(hash: String)
    case revert(hash: String)
    case reset(hash: String, mode: ResetMode)
    case copyHash(hash: String, short: Bool)
    case compareWithWorkingTree(hash: String)
}

enum ResetMode: String {
    case soft = "--soft"
    case mixed = "--mixed"
    case hard = "--hard"
}
