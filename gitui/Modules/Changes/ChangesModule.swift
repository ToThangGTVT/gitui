// MARK: - ChangesModule.swift

import Cocoa

enum ChangesModule {
    static func build() -> NSViewController {
        let view = ChangesViewController(nibName: "ChangesViewController", bundle: nil)
        let interactor = ChangesInteractor()
        let router = ChangesRouter()
        let presenter = ChangesPresenter(
            view: view,
            interactor: interactor,
            router: router
        )
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        return view
    }
}
