// MARK: - SettingsModule.swift

import Cocoa

enum SettingsModule {
    static func show(from window: NSWindow, repoPath: String?, onSave: @escaping () -> Void) {
        let view = SettingsViewController()
        let interactor = SettingsInteractor(repoPath: repoPath)
        let router = SettingsRouter()
        let presenter = SettingsPresenter(
            view: view,
            interactor: interactor,
            router: router,
            onSaveCallback: onSave
        )
        
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        
        let sheet = NSWindow(contentViewController: view)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Settings"
        sheet.setContentSize(NSSize(width: 380, height: 260))
        
        window.beginSheet(sheet, completionHandler: nil)
    }
}
