// MARK: - DiffTextView.swift

import Cocoa

protocol DiffTextViewHunkDelegate: AnyObject {
    func diffTextView(_ view: DiffTextView, didRequestStageHunk hunk: DiffHunk)
    func diffTextView(_ view: DiffTextView, didRequestDiscardHunk hunk: DiffHunk)
    func diffTextView(_ view: DiffTextView, didRequestUnstageHunk hunk: DiffHunk)
}

class DiffTextView: NSTextView {

    weak var hunkDelegate: DiffTextViewHunkDelegate?
    var hunks: [DiffHunk] = []
    var isShowingUnstagedDiff: Bool = true

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !hunks.isEmpty else { return nil }

        let pt = convert(event.locationInWindow, from: nil)
        let charIdx = characterIndexForInsertion(at: pt)
        let line = lineIndex(at: charIdx)

        guard let hunk = hunks.first(where: { line >= $0.startLineInText && line <= $0.endLineInText }) else {
            return nil
        }

        let menu = NSMenu()
        if isShowingUnstagedDiff {
            let stageItem = NSMenuItem(title: "Stage this hunk", action: #selector(stageHunkClicked(_:)), keyEquivalent: "")
            stageItem.representedObject = hunk
            stageItem.target = self
            menu.addItem(stageItem)

            let discardItem = NSMenuItem(title: "Discard this hunk", action: #selector(discardHunkClicked(_:)), keyEquivalent: "")
            discardItem.representedObject = hunk
            discardItem.target = self
            menu.addItem(discardItem)
        } else {
            let unstageItem = NSMenuItem(title: "Unstage this hunk", action: #selector(unstageHunkClicked(_:)), keyEquivalent: "")
            unstageItem.representedObject = hunk
            unstageItem.target = self
            menu.addItem(unstageItem)
        }

        return menu
    }

    private func lineIndex(at charIndex: Int) -> Int {
        let text = string as NSString
        var count = 0
        let end = min(charIndex, text.length)
        for i in 0..<end {
            if text.character(at: i) == 10 { count += 1 }
        }
        return count
    }

    @objc private func stageHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestStageHunk: hunk)
    }

    @objc private func discardHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestDiscardHunk: hunk)
    }

    @objc private func unstageHunkClicked(_ sender: NSMenuItem) {
        guard let hunk = sender.representedObject as? DiffHunk else { return }
        hunkDelegate?.diffTextView(self, didRequestUnstageHunk: hunk)
    }
}
