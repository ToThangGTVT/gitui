import os

modules_path = "/Users/golfzon/Documents/gitui/gitui/Modules"
modules = ["InteractiveRebase", "Blame", "Submodules", "Worktrees"]

for mod in modules:
    base_path = os.path.join(modules_path, mod)
    os.makedirs(base_path, exist_ok=True)
    
    # Subdirectories
    for sub in ["View", "Presenter", "Interactor", "Router", "Entity"]:
        os.makedirs(os.path.join(base_path, sub), exist_ok=True)
        
    # Module build file
    module_content = f"""import Cocoa

enum {mod}Module {{
    static func build() -> NSViewController {{
        let view = {mod}ViewController(nibName: "{mod}ViewController", bundle: nil)
        let interactor = {mod}Interactor()
        let router = {mod}Router()
        let presenter = {mod}Presenter(
            view: view,
            interactor: interactor,
            router: router
        )
        
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        router.presenter = presenter
        
        return view
    }}
}}
"""
    with open(os.path.join(base_path, f"{mod}Module.swift"), "w") as f:
        f.write(module_content)
        
    # View protocol & controller
    view_content = f"""import Cocoa

protocol {mod}ViewProtocol: AnyObject {{
    // Add methods for presenter to update view
}}

class {mod}ViewController: NSViewController, {mod}ViewProtocol {{
    var presenter: {mod}PresenterProtocol!
    
    override func viewDidLoad() {{
        super.viewDidLoad()
        presenter.viewDidLoad()
    }}
}}
"""
    with open(os.path.join(base_path, "View", f"{mod}ViewController.swift"), "w") as f:
        f.write(view_content)
        
    # Presenter protocol & class
    presenter_content = f"""import Foundation

protocol {mod}PresenterProtocol: AnyObject {{
    func viewDidLoad()
}}

class {mod}Presenter: {mod}PresenterProtocol {{
    weak var view: {mod}ViewProtocol?
    var interactor: {mod}InteractorProtocol
    var router: {mod}RouterProtocol
    
    init(view: {mod}ViewProtocol, interactor: {mod}InteractorProtocol, router: {mod}RouterProtocol) {{
        self.view = view
        self.interactor = interactor
        self.router = router
    }}
    
    func viewDidLoad() {{
        // Inform interactor or update view
    }}
}}
"""
    with open(os.path.join(base_path, "Presenter", f"{mod}Presenter.swift"), "w") as f:
        f.write(presenter_content)
        
    # Interactor protocol & class
    interactor_content = f"""import Foundation

protocol {mod}InteractorProtocol: AnyObject {{
    // Add methods for presenter to request data
}}

class {mod}Interactor: {mod}InteractorProtocol {{
    weak var presenter: {mod}PresenterProtocol?
}}
"""
    with open(os.path.join(base_path, "Interactor", f"{mod}Interactor.swift"), "w") as f:
        f.write(interactor_content)
        
    # Router protocol & class
    router_content = f"""import Cocoa

protocol {mod}RouterProtocol: AnyObject {{
    // Add navigation methods
}}

class {mod}Router: {mod}RouterProtocol {{
    weak var viewController: NSViewController?
    weak var presenter: {mod}PresenterProtocol?
}}
"""
    with open(os.path.join(base_path, "Router", f"{mod}Router.swift"), "w") as f:
        f.write(router_content)

print("Generated VIPER modules successfully.")
