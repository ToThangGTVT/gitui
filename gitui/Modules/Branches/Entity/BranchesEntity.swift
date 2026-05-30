// MARK: - BranchesEntity.swift

import Foundation

class BranchNode: NSObject {
    let name: String
    let isHeader: Bool
    let isRemote: Bool
    let isTag: Bool
    let isCurrent: Bool
    var children: [BranchNode] = []
    
    init(name: String, isHeader: Bool, isRemote: Bool = false, isTag: Bool = false, isCurrent: Bool = false) {
        self.name = name
        self.isHeader = isHeader
        self.isRemote = isRemote
        self.isTag = isTag
        self.isCurrent = isCurrent
    }
}
