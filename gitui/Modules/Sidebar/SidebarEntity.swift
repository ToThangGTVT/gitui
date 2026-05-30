// MARK: - SidebarEntity.swift

import Foundation

// Uses the shared RepositoryBookmark entity.
// We can define Sidebar-specific state structures here.

struct SidebarViewModel {
    var bookmarks: [RepositoryBookmark]
    var filteredBookmarks: [RepositoryBookmark]
    var activePath: String?
    var searchQuery: String
}
