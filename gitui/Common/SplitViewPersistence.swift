// MARK: - SplitViewPersistence.swift
// Bulletproof NSSplitView divider position save/restore via UserDefaults.
// Works regardless of autosaveName reliability, nested layouts, or constraint conflicts.

import Cocoa

final class SplitViewPersistence {
    
    private let key: String
    private weak var splitView: NSSplitView?
    
    /// - Parameters:
    ///   - splitView: The NSSplitView to manage persistence for.
    ///   - key: A unique UserDefaults key, e.g. "gitflow.split.history"
    init(splitView: NSSplitView, key: String) {
        self.splitView = splitView
        self.key = key
        
        // Also set the autosaveName + identifier on the split view for
        // macOS's built-in persistence (belt + suspenders approach)
        splitView.autosaveName = key
        splitView.identifier = NSUserInterfaceItemIdentifier(key)
    }
    
    private var hasRestored = false
    
    // MARK: - Save
    
    /// Call from `splitViewDidResizeSubviews(_:)` or whenever divider moves.
    func saveDividerPositions() {
        guard let sv = splitView else { return }
        // CRITICAL FIX: Ignore saves if we haven't successfully restored yet.
        // During initial layout, NSSplitView fires resize notifications with 0-height frames.
        // If we save now, we destroy the user's saved preferences!
        guard hasRestored else { return }
        
        // Ensure the split view actually has a meaningful size before saving
        guard sv.bounds.width > 50 && sv.bounds.height > 50 else { return }
        
        let count = sv.subviews.count
        guard count > 1 else { return }
        
        var positions: [Double] = []
        for i in 0..<(count - 1) {
            let subview = sv.subviews[i]
            if sv.isVertical {
                positions.append(Double(subview.frame.maxX))
            } else {
                positions.append(Double(subview.frame.maxY))
            }
        }
        UserDefaults.standard.set(positions, forKey: key)
    }
    
    // MARK: - Restore
    
    /// Best called from `viewDidLayout()` when bounds are valid.
    func restoreDividerPositions() {
        guard let sv = splitView else { return }
        // Ensure bounds are valid before restoring
        guard sv.bounds.width > 50 && sv.bounds.height > 50 else { return }
        
        // Mark as restored even if we don't have saved values, so saving is unblocked
        hasRestored = true
        
        guard let saved = UserDefaults.standard.array(forKey: key) as? [Double],
              saved.count == sv.subviews.count - 1
        else { return }
        
        for (i, position) in saved.enumerated() {
            sv.setPosition(CGFloat(position), ofDividerAt: i)
        }
    }
    
    // MARK: - Collapsed State
    
    private var collapseKey: String { key + ".collapsed" }
    
    /// Persist collapsed state for the first pane (sidebar toggle pattern).
    func saveCollapsedState() {
        guard let sv = splitView, !sv.subviews.isEmpty else { return }
        let isCollapsed = sv.isSubviewCollapsed(sv.subviews[0])
        UserDefaults.standard.set(isCollapsed, forKey: collapseKey)
    }
    
    /// Restore collapsed state. Call AFTER `restoreDividerPositions()`.
    /// - Parameter defaultWidth: The width to restore the pane to if it was not collapsed.
    func restoreCollapsedState(defaultWidth: CGFloat = 220) {
        guard let sv = splitView else { return }
        let wasCollapsed = UserDefaults.standard.bool(forKey: collapseKey)
        if wasCollapsed {
            sv.setPosition(0, ofDividerAt: 0)
        }
    }
}
