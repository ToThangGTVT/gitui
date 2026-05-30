import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 200),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.center()
        
        let toolbarContainer = NSView()
        toolbarContainer.wantsLayer = true
        toolbarContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 20
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(leftStack)
        
        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.spacing = 20
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.addSubview(rightStack)
        
        func createToolbarButton(title: String, symbolName: String) -> NSButton {
            let button = NSButton()
            button.title = title
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?.withSymbolConfiguration(config)
            }
            button.imagePosition = .imageAbove
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 11)
            return button
        }
        
        let leftButtons = [
            ("Commit", "plus.circle"),
            ("Pull", "arrow.down.circle"),
            ("Push", "arrow.up.circle"),
            ("Fetch", "arrow.clockwise.circle"),
            ("Branch", "arrow.triangle.branch"),
            ("Merge", "arrow.triangle.merge"),
            ("Stash", "archivebox")
        ]
        
        for b in leftButtons {
            leftStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1))
        }
        
        let rightButtons = [
            ("View Remote", "globe"),
            ("Show in Finder", "folder"),
            ("Terminal", "terminal"),
            ("Settings", "gearshape")
        ]
        
        for b in rightButtons {
            rightStack.addArrangedSubview(createToolbarButton(title: b.0, symbolName: b.1))
        }
        
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 20),
            leftStack.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -20),
            rightStack.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor)
        ])
        
        window.contentView = toolbarContainer
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
