// MARK: - HistoryModule.swift

import Cocoa

enum HistoryModule {
    static func build() -> NSViewController {
        let view = HistoryViewController(nibName: "HistoryViewController", bundle: nil)
        let interactor = HistoryInteractor()
        let router = HistoryRouter()
        let presenter = HistoryPresenter(
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
