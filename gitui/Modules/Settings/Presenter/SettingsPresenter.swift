// MARK: - SettingsPresenter.swift

import Foundation

protocol SettingsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didClickCancel()
    func didClickSave(name: String, email: String, editor: String)
}

class SettingsPresenter: SettingsPresenterProtocol {
    weak var view: SettingsViewProtocol?
    private let interactor: SettingsInteractorInputProtocol
    private let router: SettingsRouterProtocol
    private let onSaveCallback: () -> Void
    
    init(view: SettingsViewProtocol, interactor: SettingsInteractorInputProtocol, router: SettingsRouterProtocol, onSaveCallback: @escaping () -> Void) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.onSaveCallback = onSaveCallback
    }
    
    func viewDidLoad() {
        interactor.loadSettings()
    }
    
    func didClickCancel() {
        router.closeSettings()
    }
    
    func didClickSave(name: String, email: String, editor: String) {
        let entity = SettingsEntity(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    editor: editor.trimmingCharacters(in: .whitespacesAndNewlines))
        interactor.saveSettings(entity: entity)
    }
}

extension SettingsPresenter: SettingsInteractorOutputProtocol {
    func didLoadSettings(_ entity: SettingsEntity) {
        view?.displaySettings(name: entity.name, email: entity.email, editor: entity.editor)
    }
    
    func didSaveSettings() {
        onSaveCallback()
        router.closeSettings()
    }
    
    func didFailWithError(_ error: Error) {
        // You could add an error display function to SettingsViewProtocol if needed
        print("Settings operation failed: \(error.localizedDescription)")
    }
}
