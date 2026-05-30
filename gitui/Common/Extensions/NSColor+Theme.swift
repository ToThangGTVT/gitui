// MARK: - NSColor+Theme.swift

import Cocoa

extension NSColor {
    
    static var gitFlowBackground: NSColor {
        return NSColor.windowBackgroundColor
    }
    
    static var gitFlowSidebarBackground: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.windowBackgroundColor
        } else {
            return NSColor.controlBackgroundColor
        }
    }
    
    static var gitFlowBorder: NSColor {
        return NSColor.separatorColor
    }
    
    static var gitFlowStagedAdd: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.15, green: 0.40, blue: 0.15, alpha: 0.3)
            } else {
                return NSColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1.0)
            }
        }
    }
    
    static var gitFlowStagedAddText: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.40, green: 0.90, blue: 0.40, alpha: 1.0)
            } else {
                return NSColor(red: 0.10, green: 0.50, blue: 0.10, alpha: 1.0)
            }
        }
    }
    
    static var gitFlowStagedDelete: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.45, green: 0.15, blue: 0.15, alpha: 0.3)
            } else {
                return NSColor(red: 0.98, green: 0.88, blue: 0.88, alpha: 1.0)
            }
        }
    }
    
    static var gitFlowStagedDeleteText: NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.95, green: 0.45, blue: 0.45, alpha: 1.0)
            } else {
                return NSColor(red: 0.70, green: 0.15, blue: 0.15, alpha: 1.0)
            }
        }
    }
    
    static var gitFlowText: NSColor {
        return NSColor.labelColor
    }
    
    static var gitFlowSecondaryText: NSColor {
        return NSColor.secondaryLabelColor
    }
    
    static var gitFlowAccent: NSColor {
        return NSColor.controlAccentColor
    }
}
