// MARK: - SettingsInteractor.swift

import Foundation

protocol SettingsInteractorInputProtocol: AnyObject {
    func loadSettings()
    func saveSettings(entity: SettingsEntity)
}

protocol SettingsInteractorOutputProtocol: AnyObject {
    func didLoadSettings(_ entity: SettingsEntity)
    func didSaveSettings()
    func didFailWithError(_ error: Error)
}

class SettingsInteractor: SettingsInteractorInputProtocol {
    weak var presenter: SettingsInteractorOutputProtocol?
    private let repoPath: String?
    
    init(repoPath: String?) {
        self.repoPath = repoPath
    }
    
    func loadSettings() {
        let path = repoPath ?? "/"
        Task {
            do {
                let name = (try? await GitService.shared.runGit(["config", "user.name"], in: path)) ?? ""
                let email = (try? await GitService.shared.runGit(["config", "user.email"], in: path)) ?? ""
                let editor = (try? await GitService.shared.runGit(["config", "core.editor"], in: path)) ?? ""
                
                let entity = SettingsEntity(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    editor: editor.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    self.presenter?.didLoadSettings(entity)
                }
            }
        }
    }
    
    func saveSettings(entity: SettingsEntity) {
        let path = repoPath ?? "/"
        Task {
            do {
                if !entity.name.isEmpty {
                    _ = try? await GitService.shared.runGit(["config", "--global", "user.name", entity.name], in: path)
                }
                if !entity.email.isEmpty {
                    _ = try? await GitService.shared.runGit(["config", "--global", "user.email", entity.email], in: path)
                }
                if !entity.editor.isEmpty {
                    _ = try? await GitService.shared.runGit(["config", "--global", "core.editor", entity.editor], in: path)
                }
                
                await MainActor.run {
                    self.presenter?.didSaveSettings()
                }
            }
        }
    }
}
