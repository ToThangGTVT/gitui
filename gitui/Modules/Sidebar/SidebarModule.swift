// MARK: - SidebarModule.swift

import Cocoa

enum SidebarModule {
    static func build() -> NSViewController {
        let view = SidebarViewController(nibName: "SidebarViewController", bundle: nil)
        let interactor = SidebarInteractor()
        let router = SidebarRouter()
        let presenter = SidebarPresenter(
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
