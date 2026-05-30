// MARK: - TagsModule.swift

import Cocoa

enum TagsModule {
    static func build() -> NSViewController {
        let view = TagsViewController(nibName: "TagsViewController", bundle: nil)
        let interactor = TagsInteractor()
        let router = TagsRouter()
        let presenter = TagsPresenter(
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
