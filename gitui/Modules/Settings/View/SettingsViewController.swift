// MARK: - SettingsViewController.swift

import Cocoa

protocol SettingsViewProtocol: AnyObject {
    func displaySettings(name: String, email: String, editor: String)
}

class SettingsViewController: NSViewController, SettingsViewProtocol {
    
    var presenter: SettingsPresenterProtocol?
    
    private var nameField = NSTextField()
    private var emailField = NSTextField()
    private var editorField = NSTextField()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 260))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        presenter?.viewDidLoad()
    }
    
    private func buildUI() {
        view.wantsLayer = true
        
        func sectionLabel(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            lbl.textColor = .secondaryLabelColor
            lbl.translatesAutoresizingMaskIntoConstraints = false
            return lbl
        }
        
        func rowLabel(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.font = NSFont.systemFont(ofSize: 13)
            lbl.alignment = .right
            lbl.translatesAutoresizingMaskIntoConstraints = false
            return lbl
        }
        
        let gitSection = sectionLabel("GIT IDENTITY")
        let editorSection = sectionLabel("EDITOR")
        
        let nameLabel = rowLabel("Name:")
        let emailLabel = rowLabel("Email:")
        let editorLabel = rowLabel("Default editor:")
        
        for field in [nameField, emailField, editorField] {
            field.font = NSFont.systemFont(ofSize: 13)
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
    
    // MARK: - SettingsViewProtocol
    
    func displaySettings(name: String, email: String, editor: String) {
        nameField.stringValue = name
        emailField.stringValue = email
        editorField.stringValue = editor
    }
    
    // MARK: - Actions
    
    @objc private func cancelClicked() {
        presenter?.didClickCancel()
    }
    
    @objc private func saveClicked() {
        presenter?.didClickSave(name: nameField.stringValue,
                                email: emailField.stringValue,
                                editor: editorField.stringValue)
    }
}
