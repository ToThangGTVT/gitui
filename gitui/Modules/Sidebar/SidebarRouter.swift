// MARK: - SidebarRouter.swift

import Cocoa

protocol SidebarRouterProtocol: AnyObject {
    func showAlert(title: String, message: String, isError: Bool)
    func showOpenPanel(completion: @escaping (String?) -> Void)
    func showClonePrompt(completion: @escaping (String?, String?) -> Void)
}

class SidebarRouter: SidebarRouterProtocol {
    
    weak var viewController: NSViewController?
    
    func showAlert(title: String, message: String, isError: Bool) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = isError ? .warning : .informational
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
    
    func showOpenPanel(completion: @escaping (String?) -> Void) {
        guard let window = viewController?.view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"
        
        panel.beginSheetModal(for: window) { response in
            if response == .OK {
                completion(panel.url?.path)
            } else {
                completion(nil)
            }
        }
    }
    
    func showClonePrompt(completion: @escaping (String?, String?) -> Void) {
        guard let window = viewController?.view.window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Clone Repository"
        alert.informativeText = "Enter remote Git URL and select destination path:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Clone")
        alert.addButton(withTitle: "Cancel")
        
        // Multi-view layout container
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        
        let urlLabel = NSTextField(labelWithString: "Git Source URL:")
        urlLabel.frame = NSRect(x: 0, y: 55, width: 100, height: 18)
        container.addSubview(urlLabel)
        
        let urlField = NSTextField(frame: NSRect(x: 100, y: 53, width: 220, height: 22))
        urlField.placeholderString = "https://github.com/user/repo.git"
        container.addSubview(urlField)
        
        let destLabel = NSTextField(labelWithString: "Destination Path:")
        destLabel.frame = NSRect(x: 0, y: 25, width: 100, height: 18)
        container.addSubview(destLabel)
        
        let destField = NSTextField(frame: NSRect(x: 100, y: 23, width: 220, height: 22))
        destField.placeholderString = "/Users/username/Projects/repo"
        container.addSubview(destField)
        
        let browseButton = NSButton(title: "Browse...", target: nil, action: nil)
        browseButton.frame = NSRect(x: 235, y: -5, width: 90, height: 24)
        browseButton.bezelStyle = .push
        container.addSubview(browseButton)
        
        // Browse action block
        browseButton.target = self
        browseButton.action = #selector(browseFolderClicked(_:))
        
        objc_setAssociatedObject(self, &destFieldKey, destField, .OBJC_ASSOCIATION_ASSIGN)
        
        alert.accessoryView = container
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let url = urlField.stringValue
                let path = destField.stringValue
                if !url.isEmpty && !path.isEmpty {
                    completion(url, path)
                } else {
                    completion(nil, nil)
                }
            } else {
                completion(nil, nil)
            }
        }
    }
    
    private var destFieldKey: UInt8 = 0
    
    @objc private func browseFolderClicked(_ sender: NSButton) {
        guard let window = viewController?.view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let self = self {
                if let destField = objc_getAssociatedObject(self, &self.destFieldKey) as? NSTextField {
                    destField.stringValue = panel.url?.path ?? ""
                }
            }
        }
    }
}
