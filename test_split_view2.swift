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
        if #available(macOS 10.14, *) {
            split.arrangesAllSubviews = true
        }
        
        for i in 1...3 {
            let v = NSView()
            v.translatesAutoresizingMaskIntoConstraints = false
            v.heightAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(i * 100)).isActive = true
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
