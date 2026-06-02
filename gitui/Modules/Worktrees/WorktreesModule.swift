import Cocoa

enum WorktreesModule {
    static func build() -> NSViewController {
        let view = WorktreesViewController(nibName: "WorktreesViewController", bundle: nil)
        let interactor = WorktreesInteractor()
        let router = WorktreesRouter()
        let presenter = WorktreesPresenter(
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
