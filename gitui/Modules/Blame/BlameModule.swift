import Cocoa

enum BlameModule {
    static func build(filePath: String, commitHash: String?) -> NSViewController {
        let view = BlameViewController()
        let interactor = BlameInteractor()
        let router = BlameRouter()
        let presenter = BlamePresenter(
            view: view,
            interactor: interactor,
            router: router
        )
        presenter.currentFilePath = filePath
        presenter.currentCommitHash = commitHash
        
        view.presenter = presenter
        interactor.presenter = presenter
        router.viewController = view
        router.presenter = presenter
        
        return view
    }
}
