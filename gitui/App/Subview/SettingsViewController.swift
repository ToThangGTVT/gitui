// MARK: - SettingsViewController.swift

import Cocoa

class SettingsViewController: NSViewController {

    private var nameField   = NSTextField()
    private var emailField  = NSTextField()
    private var editorField = NSTextField()

    private var repoPath: String?
    private var onSave: (() -> Void)?

    static func show(repoPath: String?, from window: NSWindow, onSave: @escaping () -> Void) {
        let vc = SettingsViewController()
        vc.repoPath = repoPath
        vc.onSave = onSave

        let sheet = NSWindow(contentViewController: vc)
        sheet.styleMask = [.titled, .closable]
        sheet.title = "Settings"
        sheet.setContentSize(NSSize(width: 380, height: 260))
        window.beginSheet(sheet, completionHandler: nil)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadCurrentValues()
    }

    private func buildUI() {
        view.wantsLayer = true

        func sectionLabel(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = NSFont.systemFont(ofSize: 10, weight: .bold)
            lbl.textColor = .secondaryLabelColor
            lbl.translatesAutoresizingMaskIntoConstraints = false
            return lbl
        }

        func rowLabel(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = NSFont.systemFont(ofSize: 12)
            lbl.alignment = .right
            lbl.translatesAutoresizingMaskIntoConstraints = false
            return lbl
        }

        let gitSection  = sectionLabel("GIT IDENTITY")
        let editorSection = sectionLabel("EDITOR")

        let nameLabel   = rowLabel("Name:")
        let emailLabel  = rowLabel("Email:")
        let editorLabel = rowLabel("Default editor:")

        for field in [nameField, emailField, editorField] {
            field.font = NSFont.systemFont(ofSize: 12)
            field.translatesAutoresizingMaskIntoConstraints = false
        }
        editorField.placeholderString = "e.g. code, vim, nano"

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelBtn.bezelStyle = .push
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveBtn.bezelStyle = .push
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false

        for subview in [gitSection, editorSection, nameLabel, emailLabel, editorLabel,
                        nameField, emailField, editorField, separator, cancelBtn, saveBtn] {
            view.addSubview(subview as! NSView)
        }

        NSLayoutConstraint.activate([
            gitSection.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            gitSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            nameLabel.topAnchor.constraint(equalTo: gitSection.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameLabel.widthAnchor.constraint(equalToConstant: 110),

            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            emailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emailLabel.widthAnchor.constraint(equalToConstant: 110),

            emailField.centerYAnchor.constraint(equalTo: emailLabel.centerYAnchor),
            emailField.leadingAnchor.constraint(equalTo: emailLabel.trailingAnchor, constant: 8),
            emailField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            editorSection.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 20),
            editorSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            editorLabel.topAnchor.constraint(equalTo: editorSection.bottomAnchor, constant: 10),
            editorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            editorLabel.widthAnchor.constraint(equalToConstant: 110),

            editorField.centerYAnchor.constraint(equalTo: editorLabel.centerYAnchor),
            editorField.leadingAnchor.constraint(equalTo: editorLabel.trailingAnchor, constant: 8),
            editorField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            separator.topAnchor.constraint(equalTo: editorLabel.bottomAnchor, constant: 24),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cancelBtn.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),

            saveBtn.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            saveBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveBtn.widthAnchor.constraint(equalToConstant: 70),
        ])
    }

    private func loadCurrentValues() {
        let path = repoPath ?? "/"
        Task {
            let name   = (try? await GitService.shared.runGit(["config", "user.name"],  in: path)) ?? ""
            let email  = (try? await GitService.shared.runGit(["config", "user.email"], in: path)) ?? ""
            let editor = (try? await GitService.shared.runGit(["config", "core.editor"], in: path)) ?? ""
            await MainActor.run {
                self.nameField.stringValue   = name.trimmingCharacters(in: .whitespacesAndNewlines)
                self.emailField.stringValue  = email.trimmingCharacters(in: .whitespacesAndNewlines)
                self.editorField.stringValue = editor.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    @objc private func cancelClicked() {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    @objc private func saveClicked() {
        let path = repoPath ?? "/"
        let name   = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let email  = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let editor = editorField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if !name.isEmpty {
                _ = try? await GitService.shared.runGit(["config", "--global", "user.name",  name],  in: path)
            }
            if !email.isEmpty {
                _ = try? await GitService.shared.runGit(["config", "--global", "user.email", email], in: path)
            }
            if !editor.isEmpty {
                _ = try? await GitService.shared.runGit(["config", "--global", "core.editor", editor], in: path)
            }
            await MainActor.run {
                self.view.window?.sheetParent?.endSheet(self.view.window!)
                self.onSave?()
            }
        }
    }
}
