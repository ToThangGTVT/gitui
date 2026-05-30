// MARK: - NSView+Constraints.swift

import Cocoa

extension NSView {
    
    func pinToEdges(of parentView: NSView, insets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)) {
        self.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)
        
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: parentView.topAnchor, constant: insets.top),
            self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: insets.left),
            self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -insets.bottom),
            self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -insets.right)
        ])
    }
    
    func center(in parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)
        
        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor)
        ])
    }
}
