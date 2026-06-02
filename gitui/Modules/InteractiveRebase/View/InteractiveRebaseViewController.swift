import Cocoa

protocol InteractiveRebaseViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class InteractiveRebaseViewController: NSViewController, InteractiveRebaseViewProtocol {
    var presenter: InteractiveRebasePresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
