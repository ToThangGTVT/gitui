import Cocoa

protocol SubmodulesViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class SubmodulesViewController: NSViewController, SubmodulesViewProtocol {
    var presenter: SubmodulesPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
