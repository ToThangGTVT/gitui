// MARK: - RepositoryStore.swift

import Foundation

struct RepositoryBookmark: Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    
    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
    }
}

class RepositoryStore {
    static let shared = RepositoryStore()
    
    private let bookmarksKey = "gitflow_repository_bookmarks"
    private let activePathKey = "gitflow_active_repository_path"
    
    private init() {}
    
    func getBookmarks() -> [RepositoryBookmark] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([RepositoryBookmark].self, from: data)
        } catch {
            return []
        }
    }
    
    func saveBookmarks(_ bookmarks: [RepositoryBookmark]) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(data, forKey: bookmarksKey)
            NotificationCenter.default.post(name: .repositoryBookmarksChanged, object: nil)
        } catch {
            // Silently handle error
        }
    }
    
    func addBookmark(name: String, path: String) {
        var bookmarks = getBookmarks()
        // Prevent duplicate paths
        if let index = bookmarks.firstIndex(where: { $0.path == path }) {
            bookmarks[index].name = name
        } else {
            bookmarks.append(RepositoryBookmark(name: name, path: path))
        }
        saveBookmarks(bookmarks)
        setActiveRepository(path: path)
    }
    
    func removeBookmark(at index: Int) {
        var bookmarks = getBookmarks()
        guard index >= 0 && index < bookmarks.count else { return }
        let removed = bookmarks.remove(at: index)
        saveBookmarks(bookmarks)
        
        // If we removed the currently active repo, reset active repo
        if getActiveRepositoryPath() == removed.path {
            setActiveRepository(path: bookmarks.first?.path)
        }
    }
    
    func moveBookmark(from: Int, to: Int) {
        var bookmarks = getBookmarks()
        guard from >= 0 && from < bookmarks.count else { return }
        guard to >= 0 && to <= bookmarks.count else { return }
        
        let item = bookmarks.remove(at: from)
        // If we are moving downwards, adjusting the target index is necessary
        let adjustedTo = to > from ? to - 1 : to
        bookmarks.insert(item, at: adjustedTo)
        saveBookmarks(bookmarks)
    }
    
    func getActiveRepositoryPath() -> String? {
        return UserDefaults.standard.string(forKey: activePathKey)
    }
    
    func setActiveRepository(path: String?) {
        UserDefaults.standard.set(path, forKey: activePathKey)
        NotificationCenter.default.post(name: .activeRepositoryChanged, object: nil, userInfo: path != nil ? ["path": path!] : nil)
    }
}

extension Notification.Name {
    static let repositoryBookmarksChanged = Notification.Name("repositoryBookmarksChanged")
    static let activeRepositoryChanged = Notification.Name("activeRepositoryChanged")
    static let sidebarShouldRefreshStats = Notification.Name("sidebarShouldRefreshStats")
    static let repositoryContentShouldRefresh = Notification.Name("repositoryContentShouldRefresh")
    static let fileSearchQueryChanged = Notification.Name("fileSearchQueryChanged")
}
