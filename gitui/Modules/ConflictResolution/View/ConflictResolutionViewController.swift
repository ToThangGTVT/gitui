import Cocoa

protocol ConflictResolutionViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class ConflictResolutionViewController: NSViewController, ConflictResolutionViewProtocol {
    var presenter: ConflictResolutionPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
