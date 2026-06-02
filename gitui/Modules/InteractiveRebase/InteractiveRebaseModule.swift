import Cocoa

enum InteractiveRebaseModule {
    static func build(ontoHash: String) -> NSViewController {
        let view = InteractiveRebaseViewController()
        let interactor = InteractiveRebaseInteractor()
        let router = InteractiveRebaseRouter()
        let presenter = InteractiveRebasePresenter(
            view: view,
            interactor: interactor,
            router: router
        )
        presenter.ontoHash = ontoHash
        
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        router.presenter = presenter
        
        return view
    }
}
