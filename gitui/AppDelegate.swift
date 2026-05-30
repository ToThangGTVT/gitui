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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
