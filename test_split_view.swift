import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.center()
        
        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        
        for i in 1...3 {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = (i == 1 ? NSColor.red.cgColor : (i == 2 ? NSColor.green.cgColor : NSColor.blue.cgColor))
            v.translatesAutoresizingMaskIntoConstraints = true // Default
            v.autoresizingMask = [.width, .height]
            split.addArrangedSubview(v)
        }
        
        window.contentView = split
        window.makeKeyAndOrderFront(nil)
        
        // Wait 1 sec then print frames
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("Frames:")
            split.subviews.forEach { print($0.frame) }
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
