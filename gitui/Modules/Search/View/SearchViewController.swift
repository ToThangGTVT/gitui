import Cocoa

protocol SearchViewProtocol: AnyObject {
    // Add methods for presenter to update view
}

class SearchViewController: NSViewController, SearchViewProtocol {
    var presenter: SearchPresenterProtocol!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.viewDidLoad()
    }
}
