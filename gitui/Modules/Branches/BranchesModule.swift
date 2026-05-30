// MARK: - BranchesModule.swift

import Cocoa

enum BranchesModule {
    static func build() -> NSViewController {
        let view = BranchesViewController(nibName: "BranchesViewController", bundle: nil)
        let interactor = BranchesInteractor()
        let router = BranchesRouter()
        let presenter = BranchesPresenter(
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
