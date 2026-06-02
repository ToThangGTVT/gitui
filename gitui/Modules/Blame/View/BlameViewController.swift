import Cocoa

protocol BlameViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class BlameViewController: NSViewController, BlameViewProtocol {
    var presenter: BlamePresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
