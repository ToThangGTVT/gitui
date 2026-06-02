import Cocoa

enum SearchModule {
    static func build() -> NSViewController {
        let view = SearchViewController(nibName: "SearchViewController", bundle: nil)
        let interactor = SearchInteractor()
        let router = SearchRouter()
        let presenter = SearchPresenter(
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
