import Cocoa

enum ConflictResolutionModule {
    static func build() -> NSViewController {
        let view = ConflictResolutionViewController(nibName: "ConflictResolutionViewController", bundle: nil)
        let interactor = ConflictResolutionInteractor()
        let router = ConflictResolutionRouter()
        let presenter = ConflictResolutionPresenter(
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
