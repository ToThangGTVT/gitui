// MARK: - CustomToolbarView.swift

import Cocoa
import Combine
import SwiftUI

protocol CustomToolbarViewDelegate: AnyObject {
    func toolbarDidClickCommit()
    func toolbarDidClickPull()
    func toolbarDidClickPush()
    func toolbarDidClickFetch()
    func toolbarDidClickBranch()
    func toolbarDidClickMerge()
    func toolbarDidClickStash()
    func toolbarDidClickViewRemote()
    func toolbarDidClickShowInFinder()
    func toolbarDidClickTerminal()
    func toolbarDidClickSettings()
}

final class CustomToolbarView: NSView {

    weak var delegate: CustomToolbarViewDelegate?

    private let state = ToolbarState()
    private var hostingView: NSHostingView<ToolbarRootView>?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSwiftUIView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSwiftUIView()
    }

    func setPullBadge(count: Int) {
        state.pullBadgeCount = count
    }

    func setPushBadge(count: Int) {
        state.pushBadgeCount = count
    }

    private func setupSwiftUIView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let rootView = ToolbarRootView(state: state) { [weak self] action in
            self?.handle(action: action)
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    private func handle(action: ToolbarAction) {
        switch action {
        case .commit:
            delegate?.toolbarDidClickCommit()
        case .pull:
            delegate?.toolbarDidClickPull()
        case .push:
            delegate?.toolbarDidClickPush()
        case .fetch:
            delegate?.toolbarDidClickFetch()
        case .branch:
            delegate?.toolbarDidClickBranch()
        case .merge:
            delegate?.toolbarDidClickMerge()
        case .stash:
            delegate?.toolbarDidClickStash()
        case .viewRemote:
            delegate?.toolbarDidClickViewRemote()
        case .showInFinder:
            delegate?.toolbarDidClickShowInFinder()
        case .terminal:
            delegate?.toolbarDidClickTerminal()
        case .settings:
            delegate?.toolbarDidClickSettings()
        }
    }
}

private enum ToolbarAction: String, CaseIterable, Identifiable {
    case commit
    case pull
    case push
    case fetch
    case branch
    case merge
    case stash
    case viewRemote
    case showInFinder
    case terminal
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commit:
            return "Commit"
        case .pull:
            return "Pull"
        case .push:
            return "Push"
        case .fetch:
            return "Fetch"
        case .branch:
            return "Branch"
        case .merge:
            return "Merge"
        case .stash:
            return "Stash"
        case .viewRemote:
            return "View Remote"
        case .showInFinder:
            return "Show in Finder"
        case .terminal:
            return "Terminal"
        case .settings:
            return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .commit:
            return "plus.circle"
        case .pull:
            return "arrow.down.circle"
        case .push:
            return "arrow.up.circle"
        case .fetch:
            return "arrow.clockwise.circle"
        case .branch:
            return "arrow.triangle.branch"
        case .merge:
            return "arrow.triangle.merge"
        case .stash:
            return "archivebox"
        case .viewRemote:
            return "globe"
        case .showInFinder:
            return "folder"
        case .terminal:
            return "terminal"
        case .settings:
            return "gearshape"
        }
    }

    var isPrimary: Bool {
        self == .commit
    }
}

private final class ToolbarState: ObservableObject {
    @Published var pullBadgeCount = 0
    @Published var pushBadgeCount = 0

    func badgeCount(for action: ToolbarAction) -> Int {
        switch action {
        case .pull:
            return pullBadgeCount
        case .push:
            return pushBadgeCount
        default:
            return 0
        }
    }
}

private struct ToolbarRootView: View {
    @ObservedObject var state: ToolbarState
    let onAction: (ToolbarAction) -> Void

    private let leftActions: [ToolbarAction] = [
        .commit, .pull, .push, .fetch, .branch, .merge, .stash
    ]

    private let rightActions: [ToolbarAction] = [
        .viewRemote, .showInFinder, .terminal, .settings
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            toolbarGroup(leftActions)
            Spacer(minLength: 32)
            toolbarGroup(rightActions)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .m3OutlineFaint))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func toolbarGroup(_ actions: [ToolbarAction]) -> some View {
        HStack(alignment: .center, spacing: 15) {
            ForEach(actions) { action in
                ToolbarButtonView(
                    action: action,
                    badgeCount: state.badgeCount(for: action),
                    onTap: onAction
                )
            }
        }
    }
}

private struct ToolbarButtonView: View {
    let action: ToolbarAction
    let badgeCount: Int
    let onTap: (ToolbarAction) -> Void

    var body: some View {
        Button {
            onTap(action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 19, weight: .regular))
                    .overlay(alignment: .topTrailing) {
                        if badgeCount > 0 {
                            ToolbarBadgeView(
                                count: badgeCount,
                                color: Color(nsColor: .systemBlue),
                                fontSize: 10,
                                horizontalPadding: 5,
                                minSize: 12
                            )
                            .offset(x: 8, y: -4)
                        }
                    }
                Text(action.title)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
            .foregroundStyle(Color(nsColor: action.isPrimary ? .systemBlue : .labelColor))
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct ToolbarBadgeView: View {
    let count: Int
    let color: Color
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let minSize: CGFloat

    var body: some View {
        Text("\(count)")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: minSize, minHeight: minSize)
            .background(color)
            .clipShape(Capsule())
    }
}
