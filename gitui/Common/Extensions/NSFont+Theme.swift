// MARK: - NSFont+Theme.swift

import Cocoa

extension NSFont {
    
    // Helper to fall back to system font if Roboto is unavailable
    private static func materialFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        // We can try to load "Roboto" here if it exists in the bundle
        if let roboto = NSFont(name: "Roboto-Regular", size: size) {
            // Very naive way to handle weight if multiple fonts are available, 
            // but usually we rely on system font for safety if custom font isn't embedded.
            return roboto
        }
        return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
    
    private static func materialMonoFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
    
    // MARK: - Material 3 Typography
    
    static var m3TitleLarge: NSFont { materialFont(ofSize: 40, weight: .medium) } // 500
    static var m3Headline: NSFont { materialFont(ofSize: 25, weight: .medium) }   // 500
    static var m3Title: NSFont { materialFont(ofSize: 15, weight: .semibold) }    // 600
    static var m3Body: NSFont { materialFont(ofSize: 14, weight: .regular) }      // 400
    static var m3BodyCompact: NSFont { materialFont(ofSize: 13, weight: .regular) } // 400
    static var m3Label: NSFont { materialFont(ofSize: 12, weight: .medium) }      // 500
    static var m3Overline: NSFont { materialFont(ofSize: 11, weight: .bold) }     // 700
    
    // Mono styles
    static var m3Mono: NSFont { materialMonoFont(ofSize: 12, weight: .regular) }
    static var m3MonoCompact: NSFont { materialMonoFont(ofSize: 11, weight: .regular) }
}
