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
            split.addSubview(v)
            
            split.setHoldingPriority(NSLayoutConstraint.Priority(249 + Float(i)), forSubviewAt: i - 1)
        }
        
        window.contentView = split
        window.makeKeyAndOrderFront(nil)
        
        // Emulate restoring AFTER initial layout (which gave them 0 height)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Frames before setPosition:")
            self.split.subviews.forEach { print($0.frame) }
            
            self.split.setPosition(200, ofDividerAt: 0)
            self.split.setPosition(400, ofDividerAt: 1)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("Frames after setPosition:")
            self.split.subviews.forEach { print($0.frame) }
            NSApp.terminate(nil)
        }
    }
    
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 { return 80 }
        if dividerIndex == 1 { return splitView.subviews[0].frame.maxY + 1 + 80 }
        return proposedMinimumPosition
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 { return splitView.subviews[1].frame.maxY - 1 - 80 }
        if dividerIndex == 1 { return splitView.bounds.height - 100 - 1 }
        return proposedMaximumPosition
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
