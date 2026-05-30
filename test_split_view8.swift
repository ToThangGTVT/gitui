import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSSplitViewDelegate {
    var window: NSWindow!
    var split: NSSplitView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.center()
        
        split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.delegate = self
        
        for i in 1...3 {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = (i == 1 ? NSColor.red.cgColor : (i == 2 ? NSColor.green.cgColor : NSColor.blue.cgColor))
            v.translatesAutoresizingMaskIntoConstraints = true
            v.autoresizingMask = [.width, .height]
            v.frame = NSRect(x: 0, y: 0, width: 400, height: 100)
            split.addSubview(v)
            
            split.setHoldingPriority(NSLayoutConstraint.Priority(249 + Float(i)), forSubviewAt: i - 1)
        }
        
        window.contentView = split
        window.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Before manual frames:")
            self.split.subviews.forEach { print($0.frame) }
            
            let panes = self.split.subviews
            let divT = self.split.dividerThickness
            let total = self.split.bounds.height
            
            let pos0: CGFloat = 80
            let pos1: CGFloat = 300
            
            panes[0].frame = NSRect(x: 0, y: 0, width: panes[0].bounds.width, height: pos0)
            panes[1].frame = NSRect(x: 0, y: pos0 + divT, width: panes[1].bounds.width, height: pos1 - pos0 - divT)
            panes[2].frame = NSRect(x: 0, y: pos1 + divT, width: panes[2].bounds.width, height: total - pos1 - divT)
            
            self.split.adjustSubviews()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("After manual frames:")
            self.split.subviews.forEach { print($0.frame) }
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
