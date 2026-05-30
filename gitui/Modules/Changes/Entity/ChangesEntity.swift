// MARK: - ChangesEntity.swift

import Foundation

// For the Changes module, we use the shared GitFileStatus entity.
// We can define any module-specific UI-facing models or options here.

struct ChangesViewModel {
    var stagedFiles: [GitFileStatus]
    var unstagedFiles: [GitFileStatus]
    var selectedFile: GitFileStatus?
    var diffContent: String?
}
