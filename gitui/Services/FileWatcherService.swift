// MARK: - FileWatcherService.swift

import Foundation

/// Watches a single directory tree for file-system changes using macOS FSEvents.
/// Posts `Notification.Name.repositoryFilesChanged` when changes are detected.
///
/// Design choices for performance:
/// - Only watches the **active** repo (one stream at a time).
/// - FSEvents coalesces events internally; we add an extra debounce timer
///   so rapid bursts (e.g. `git checkout`) produce at most one notification.
/// - Latency is set to 1.5 seconds — FSEvents batches events for this duration
///   before delivering them, avoiding per-file callbacks.
/// - Ignores `.git/objects` pack/loose-object churn to reduce noise.

class FileWatcherService {
    static let shared = FileWatcherService()
    
    private var stream: FSEventStreamRef?
    private var watchedPath: String?
    
    /// Extra debounce on top of FSEvents latency to coalesce multi-event bursts.
    private var debounceTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 2.0  // seconds
    
    private init() {}
    
    deinit {
        stopWatching()
    }
    
    // MARK: - Public API
    
    /// Start watching a repo directory. Automatically stops any previous watch.
    func watch(repoPath: String) {
        // Skip if already watching this exact path
        if watchedPath == repoPath, stream != nil { return }
        
        stopWatching()
        watchedPath = repoPath
        
        let pathsToWatch = [repoPath] as CFArray
        
        // FSEvents callback — must be a C-function pointer, so we use a free function
        // and pass `self` via the context info pointer.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let flags: UInt32 = UInt32(kFSEventStreamCreateFlagUseCFTypes)
        
        guard let newStream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,  // latency in seconds — FSEvents batches events for this duration
            FSEventStreamCreateFlags(flags)
        ) else { return }
        
        stream = newStream
        FSEventStreamSetDispatchQueue(newStream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(newStream)
    }
    
    /// Stop watching the current directory.
    func stopWatching() {
        debounceTimer?.cancel()
        debounceTimer = nil
        
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        watchedPath = nil
    }
    
    // MARK: - Internal
    
    fileprivate func handleFSEvent() {
        // Debounce: reset the timer on every burst of events
        debounceTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            guard self?.watchedPath != nil else { return }
            NotificationCenter.default.post(name: .repositoryFilesChanged, object: nil)
        }
        timer.resume()
        debounceTimer = timer
    }
}

// MARK: - FSEvents C callback

/// Free function required by FSEventStreamCreate (cannot be a closure or method).
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()
    
    // Filter: ignore all .git/ internal changes (index, refs, objects, logs...)
    // Only react to working-tree file changes.
    if let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] {
        let hasWorkingTreeChange = paths.contains { path in
            !path.contains("/.git/") && !path.hasSuffix("/.git")
        }
        guard hasWorkingTreeChange else { return }
    }
    
    watcher.handleFSEvent()
}

// MARK: - Notification Name

extension Notification.Name {
    static let repositoryFilesChanged = Notification.Name("repositoryFilesChanged")
}
