// MARK: - RemotesModule.swift

import Cocoa

enum RemotesModule {
    static func build() -> NSViewController {
        let view = RemotesViewController(nibName: "RemotesViewController", bundle: nil)
        let interactor = RemotesInteractor()
        let router = RemotesRouter()
        let presenter = RemotesPresenter(
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
