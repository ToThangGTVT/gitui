import Cocoa

protocol WorktreesViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class WorktreesViewController: NSViewController, WorktreesViewProtocol {
    var presenter: WorktreesPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
