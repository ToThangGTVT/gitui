// MARK: - NSColor+Theme.swift

import Cocoa

extension NSColor {
    
    // Helper to create colors from hex strings
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    // MARK: - Material 3 Neutral Surfaces (Light)
    static var m3Surface: NSColor { NSColor(hex: "#FCFCFF") }
    static var m3SurfaceContainerLowest: NSColor { NSColor(hex: "#FFFFFF") }
    static var m3SurfaceContainerLow: NSColor { NSColor(hex: "#F6F7FB") }
    static var m3SurfaceContainer: NSColor { NSColor(hex: "#F0F2F7") }
    static var m3SurfaceContainerHigh: NSColor { NSColor(hex: "#EAECF2") }
    static var m3SurfaceContainerHighest: NSColor { NSColor(hex: "#E4E6EC") }

    // MARK: - Material 3 Text & Outlines
    static var m3OnSurface: NSColor { NSColor(hex: "#1A1C1F") }
    static var m3OnSurfaceVariant: NSColor { NSColor(hex: "#44474E") }
    static var m3OnSurfaceFaint: NSColor { NSColor(hex: "#74777F") }
    static var m3OutlineVariant: NSColor { NSColor(hex: "#C4C6CF") }
    static var m3OutlineFaint: NSColor { NSColor(hex: "#E2E3EA") }

    // MARK: - Material 3 Accents
    static var m3Primary: NSColor { NSColor(hex: "#1A73E8") }
    static var m3PrimaryContainer: NSColor { NSColor(hex: "#E1EBFB") } // approx 13% over white
    static var m3OnPrimaryContainer: NSColor { NSColor(hex: "#001D35") } // dark contrast

    // MARK: - Existing GitFlow mappings updated to Material 3
    
    static var gitFlowBackground: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.windowBackgroundColor : NSColor.m3Surface
        }
    }
    
    static var gitFlowSidebarBackground: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.controlBackgroundColor : NSColor.m3SurfaceContainer
        }
    }
    
    static var gitFlowBorder: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.separatorColor : NSColor.m3OutlineFaint
        }
    }
    
    // MARK: - Git Semantic Colors
    
    static var gitFlowStagedAdd: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.15, green: 0.40, blue: 0.15, alpha: 0.3) : NSColor(hex: "#E6F4EA")
        }
    }
    
    static var gitFlowStagedAddText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.40, green: 0.90, blue: 0.40, alpha: 1.0) : NSColor(hex: "#1E8E3E")
        }
    }
    
    static var gitFlowStagedDelete: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.45, green: 0.15, blue: 0.15, alpha: 0.3) : NSColor(hex: "#FCE8E6")
        }
    }
    
    static var gitFlowStagedDeleteText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.95, green: 0.45, blue: 0.45, alpha: 1.0) : NSColor(hex: "#D93025")
        }
    }

    static var gitFlowModified: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.45, green: 0.35, blue: 0.05, alpha: 0.5) : NSColor(hex: "#FEEFC3")
        }
    }

    static var gitFlowModifiedText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1.0) : NSColor(hex: "#E37400")
        }
    }
    
    static var gitFlowRenamed: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 0.3) : NSColor(hex: "#F3E8FF")
        }
    }
    
    static var gitFlowRenamedText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.80, green: 0.40, blue: 1.0, alpha: 1.0) : NSColor(hex: "#8430CE")
        }
    }
    
    static var gitFlowConflict: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.50, green: 0.20, blue: 0.00, alpha: 0.45) : NSColor(hex: "#FEEFC3")
        }
    }

    static var gitFlowConflictText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1.0) : NSColor(hex: "#E37400")
        }
    }
    
    // MARK: - Diff Colors

    static var gitFlowDiffContextText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.82, alpha: 1.0)
                : NSColor.m3OnSurfaceVariant
        }
    }

    static var gitFlowDiffLineNum: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.45, alpha: 1.0)
                : NSColor.m3OnSurfaceFaint
        }
    }

    static var gitFlowText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.labelColor : NSColor.m3OnSurface
        }
    }
    
    static var gitFlowSecondaryText: NSColor {
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.secondaryLabelColor : NSColor.m3OnSurfaceVariant
        }
    }
    
    static var gitFlowAccent: NSColor {
        return NSColor.m3Primary
    }
}

