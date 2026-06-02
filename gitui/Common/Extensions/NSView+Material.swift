// MARK: - NSView+Material.swift

import Cocoa

extension NSView {
    
    enum MaterialRadius: CGFloat {
        case xs = 8.0
        case sm = 12.0
        case md = 16.0
        case btn = 20.0
    }
    
    func applyMaterialCornerRadius(_ radius: MaterialRadius) {
        self.wantsLayer = true
        self.layer?.cornerRadius = radius.rawValue
        self.layer?.masksToBounds = true
    }
    
    func applyMaterialFullCornerRadius() {
        self.wantsLayer = true
        self.layer?.cornerRadius = min(self.bounds.width, self.bounds.height) / 2.0
        self.layer?.masksToBounds = true
    }
    
    enum MaterialElevation {
        case level1
        case level2
        case level3
    }
    
    func applyMaterialElevation(_ elevation: MaterialElevation) {
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        
        // Subtle shadows to replace heavy drop shadows as per M3 specs
        let shadowColor = NSColor.black.withAlphaComponent(0.15).cgColor
        
        switch elevation {
        case .level1:
            self.layer?.shadowColor = shadowColor
            self.layer?.shadowOpacity = 1.0
            self.layer?.shadowOffset = CGSize(width: 0, height: -1)
            self.layer?.shadowRadius = 2.0
        case .level2:
            self.layer?.shadowColor = shadowColor
            self.layer?.shadowOpacity = 1.0
            self.layer?.shadowOffset = CGSize(width: 0, height: -2)
            self.layer?.shadowRadius = 4.0
        case .level3:
            self.layer?.shadowColor = shadowColor
            self.layer?.shadowOpacity = 1.0
            self.layer?.shadowOffset = CGSize(width: 0, height: -4)
            self.layer?.shadowRadius = 8.0
        }
    }
}
