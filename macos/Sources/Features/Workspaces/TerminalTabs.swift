import AppKit
import Combine
import GhosttyKit

/// One tab: a split tree that is only mounted in the window while it is the
/// active tab of the active workspace. Unmounted trees keep their surfaces
/// (and processes) alive.
final class TerminalTab: ObservableObject, Identifiable {
    let id = UUID()
    var surfaceTree: SplitTree<Ghostty.SurfaceView> {
        didSet { observeBell() }
    }
    weak var focusedSurface: Ghostty.SurfaceView? {
        didSet { observeTitle() }
    }
    var titleOverride: String? {
        didSet { objectWillChange.send() }
    }

    /// Title of the focused surface (without override).
    @Published private(set) var title: String = "👻"

    /// True while any surface in this tab has an active bell. Surfaces clear
    /// their bell on focus or key press, so this clears when the tab is used.
    @Published private(set) var hasBell: Bool = false

    private var titleCancellable: AnyCancellable?
    private var bellCancellable: AnyCancellable?

    var displayTitle: String { titleOverride ?? title }

    var needsConfirmClose: Bool { surfaceTree.contains { $0.needsConfirmQuit } }

    init(surfaceTree: SplitTree<Ghostty.SurfaceView>, focusedSurface: Ghostty.SurfaceView? = nil, titleOverride: String? = nil) {
        self.surfaceTree = surfaceTree
        self.focusedSurface = focusedSurface ?? surfaceTree.first
        self.titleOverride = titleOverride
        observeTitle()
        observeBell()
    }

    private func observeBell() {
        let surfaces = Array(surfaceTree)
        // Published emits on willSet, so re-read the values on the next main
        // queue turn instead of using the emitted value.
        bellCancellable = Publishers.MergeMany(surfaces.map { $0.$bell.map { _ in } })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.hasBell = self.surfaceTree.contains { $0.bell }
            }
        hasBell = surfaces.contains { $0.bell }
    }

    private func observeTitle() {
        guard let surface = focusedSurface ?? surfaceTree.first else {
            titleCancellable = nil
            return
        }
        titleCancellable = surface.$title.sink { [weak self] in self?.title = $0 }
    }
}

/// A named group of tabs.
final class Workspace: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var tabs: [TerminalTab]
    @Published var activeTab: TerminalTab?

    /// True while any tab in this workspace has an active bell.
    @Published private(set) var hasBell: Bool = false
    private var bellCancellable: AnyCancellable?

    init(name: String, tabs: [TerminalTab], activeTab: TerminalTab? = nil) {
        self.name = name
        self.tabs = tabs
        self.activeTab = activeTab ?? tabs.first
        bellCancellable = $tabs
            .map { tabs in
                Publishers.MergeMany(tabs.map(\.$hasBell))
                    .map { _ in tabs.contains { $0.hasBell } }
                    .prepend(tabs.contains { $0.hasBell })
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.hasBell = self.tabs.contains { $0.hasBell }
            }
    }

    func index(of tab: TerminalTab) -> Int? { tabs.firstIndex { $0 === tab } }

    var needsConfirmClose: Bool { tabs.contains { $0.needsConfirmClose } }
}

/// All workspaces of one window.
final class WorkspaceList: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var active: Workspace?
    private var counter = 0

    func index(of ws: Workspace) -> Int? { workspaces.firstIndex { $0 === ws } }

    func nextName() -> String {
        counter += 1
        return "Workspace \(counter)"
    }

    var allTabs: [TerminalTab] { workspaces.flatMap(\.tabs) }
    var allSurfaces: [Ghostty.SurfaceView] { allTabs.flatMap { Array($0.surfaceTree) } }
}
