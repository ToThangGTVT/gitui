// MARK: - SettingsRouter.swift

import Cocoa

protocol SettingsRouterProtocol: AnyObject {
    func closeSettings()
}

class SettingsRouter: SettingsRouterProtocol {
    weak var viewController: NSViewController?
    
    func closeSettings() {
        if let window = viewController?.view.window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            viewController?.dismiss(nil)
        }
    }
}
