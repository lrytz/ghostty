import AppKit

extension TerminalRestorableState {
    /// Internal State we use to perform unit tests
    ///
    /// Since we can't really change the type of `TerminalRestorableState`
    /// due to `CodableBridge<TerminalRestorableState>` supporting secure coding,
    /// we use an internal type to perform migration and tests
    struct InternalState<ViewType: NSView & Codable & Identifiable>: Codable {
        // MARK: - Version 5 (1.2.3)
        let focusedSurface: String?
        let surfaceTree: SplitTree<ViewType>

        // MARK: - Version 7 (1.3.0)
        let effectiveFullscreenMode: FullscreenMode?
        let tabColor: TerminalTabColor?
        let titleOverride: String?

        // MARK: - Version 8 (workspaces fork)
        let workspaces: [WorkspaceState<ViewType>]?
        let activeWorkspace: Int?
    }

    struct WorkspaceState<ViewType: NSView & Codable & Identifiable>: Codable {
        let name: String
        let tabs: [TabState<ViewType>]
        let activeTab: Int
    }

    struct TabState<ViewType: NSView & Codable & Identifiable>: Codable {
        let surfaceTree: SplitTree<ViewType>
        let focusedSurface: String?
        let titleOverride: String?
    }
}

extension TerminalRestorableState.InternalState where ViewType == Ghostty.SurfaceView {
    init(from controller: TerminalController) {
        let list = controller.workspaces
        self.init(
            focusedSurface: controller.focusedSurface?.id.uuidString,
            surfaceTree: controller.surfaceTree,
            effectiveFullscreenMode: controller.fullscreenStyle?.fullscreenMode,
            tabColor: (controller.window as? TerminalWindow)?.tabColor,
            titleOverride: controller.titleOverride,
            workspaces: list.workspaces.map { ws in
                .init(
                    name: ws.name,
                    tabs: ws.tabs.map { tab in
                        .init(
                            surfaceTree: tab.surfaceTree,
                            focusedSurface: tab.focusedSurface?.id.uuidString,
                            titleOverride: tab.titleOverride)
                    },
                    activeTab: ws.activeTab.flatMap { ws.index(of: $0) } ?? 0)
            },
            activeWorkspace: list.active.flatMap { list.index(of: $0) } ?? 0,
        )
    }

    /// Rebuild the workspace model; nil for states saved before workspaces existed.
    func makeWorkspaceList() -> WorkspaceList? {
        guard let workspaces, !workspaces.isEmpty else { return nil }
        let list = WorkspaceList()
        for ws in workspaces where !ws.tabs.isEmpty {
            let tabs = ws.tabs.map { tab in
                TerminalTab(
                    surfaceTree: tab.surfaceTree,
                    focusedSurface: tab.focusedSurface.flatMap { id in tab.surfaceTree.first { $0.id.uuidString == id } },
                    titleOverride: tab.titleOverride)
            }
            let workspace = Workspace(name: ws.name, tabs: tabs, activeTab: tabs[min(max(ws.activeTab, 0), tabs.count - 1)])
            list.workspaces.append(workspace)
            _ = list.nextName()
        }
        guard !list.workspaces.isEmpty else { return nil }
        list.active = list.workspaces[min(max(activeWorkspace ?? 0, 0), list.workspaces.count - 1)]
        return list
    }
}
