import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.center()
        window.title = "Test"
        
        let contentView = window.contentView!
        
        // Emulate mainSplitView
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.red.cgColor
        contentView.addSubview(splitView)
        
        // Normally splitView is pinned to contentView.
        // Let's remove any constraints (simulating programmatically taking over)
        splitView.removeFromSuperview()
        contentView.addSubview(splitView)
        
        // Create custom toolbar
        let toolbarContainer = NSView()
        toolbarContainer.wantsLayer = true
        toolbarContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarContainer)
        
        let label = NSTextField(labelWithString: "Toolbar Content Here")
        label.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: toolbarContainer.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            
            toolbarContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 60),
            
            splitView.topAnchor.constraint(equalTo: toolbarContainer.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        window.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
