import Cocoa

enum SubmodulesModule {
    static func build() -> NSViewController {
        let view = SubmodulesViewController(nibName: "SubmodulesViewController", bundle: nil)
        let interactor = SubmodulesInteractor()
        let router = SubmodulesRouter()
        let presenter = SubmodulesPresenter(
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
