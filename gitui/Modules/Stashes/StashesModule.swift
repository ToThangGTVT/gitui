// MARK: - StashesModule.swift

import Cocoa

enum StashesModule {
    static func build() -> NSViewController {
        let view = StashesViewController(nibName: "StashesViewController", bundle: nil)
        let interactor = StashesInteractor()
        let router = StashesRouter()
        let presenter = StashesPresenter(
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
