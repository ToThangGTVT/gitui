import Cocoa

enum InteractiveRebaseModule {
    static func build() -> NSViewController {
        let view = InteractiveRebaseViewController(nibName: "InteractiveRebaseViewController", bundle: nil)
        let interactor = InteractiveRebaseInteractor()
        let router = InteractiveRebaseRouter()
        let presenter = InteractiveRebasePresenter(
            view: view,
            interactor: interactor,
            router: router
        )
        
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        router.presenter = presenter
        
        return view
    }
}
