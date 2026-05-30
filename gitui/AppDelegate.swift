// MARK: - AppDelegate.swift

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize the main window controller and show the window
        let controller = MainWindowController()
        controller.showWindow(nil)
        self.mainWindowController = controller
        
        // Dynamically add the Update check to the Application Menu
        setupUpdateMenu()
        
        // Silently check for updates in the background 2 seconds after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkForUpdates(nil)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Update Check Integration
    
    private func setupUpdateMenu() {
        guard let mainMenu = NSApp.mainMenu,
              let appMenuItem = mainMenu.item(at: 0),
              let appMenu = appMenuItem.submenu else {
            return
        }
        
        // Check if item already exists to prevent duplicate insertion
        if appMenu.items.contains(where: { $0.action == #selector(checkForUpdates(_:)) }) {
            return
        }
        
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        
        // Insert after "About gitui" (index 0) and before the first separator (index 1)
        if appMenu.numberOfItems > 1 {
            appMenu.insertItem(updateItem, at: 1)
        } else {
            appMenu.addItem(updateItem)
        }
    }
    
    @objc func checkForUpdates(_ sender: Any?) {
        let isManual = (sender != nil)
        
        Task {
            do {
                let latestRelease = try await UpdateService.shared.getLatestRelease()
                let currentVersion = UpdateService.shared.getCurrentVersion()
                
                await MainActor.run {
                    if UpdateService.shared.isNewerVersion(current: currentVersion, latest: latestRelease.tagName) {
                        // Present gorgeous update sheet
                        let targetWindow = self.mainWindowController?.window
                        UpdateViewController.show(release: latestRelease, currentVersion: currentVersion, from: targetWindow)
                    } else if isManual {
                        // Show "Up to date" popup for manual triggers only
                        let alert = NSAlert()
                        alert.messageText = "Up to Date"
                        alert.informativeText = "gitui \(currentVersion) is currently the newest version available."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        
                        if let window = self.mainWindowController?.window {
                            alert.beginSheetModal(for: window, completionHandler: nil)
                        } else {
                            alert.runModal()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if isManual {
                        // Show error alert for manual triggers only
                        let alert = NSAlert()
                        alert.messageText = "Update Check Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        
                        if let window = self.mainWindowController?.window {
                            alert.beginSheetModal(for: window, completionHandler: nil)
                        } else {
                            alert.runModal()
                        }
                    } else {
                        // Fail silently for automatic background checks
                        print("Background update check failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

