import Cocoa

enum BlameModule {
    static func build() -> NSViewController {
        let view = BlameViewController(nibName: "BlameViewController", bundle: nil)
        let interactor = BlameInteractor()
        let router = BlameRouter()
        let presenter = BlamePresenter(
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
