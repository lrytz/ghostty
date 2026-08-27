import AppKit
import GhosttyKit

/// The "Workspace" app menu. Actions route to the key terminal window.
final class WorkspaceManager: NSObject {
    static let shared = WorkspaceManager()

    private(set) var menuNew: NSMenuItem?
    private(set) var menuClose: NSMenuItem?
    private(set) var menuRename: NSMenuItem?
    private(set) var menuPrevious: NSMenuItem?
    private(set) var menuNext: NSMenuItem?

    private var keyController: TerminalController? {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.windowController as? TerminalController
    }

    /// Insert a "Workspace" menu before the Window menu.
    func installMenu(before windowMenuItem: NSMenuItem?) {
        guard let mainMenu = NSApp.mainMenu else { return }
        let menu = NSMenu(title: "Workspace")
        func item(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            return item
        }
        menuNew = item("New Workspace", #selector(newWorkspace(_:)))
        menuClose = item("Close Workspace", #selector(closeWorkspace(_:)))
        menuRename = item("Rename Workspace…", #selector(renameWorkspace(_:)))
        menu.addItem(.separator())
        menuPrevious = item("Previous Workspace", #selector(previousWorkspace(_:)))
        menuNext = item("Next Workspace", #selector(nextWorkspace(_:)))

        let menuItem = NSMenuItem(title: "Workspace", action: nil, keyEquivalent: "")
        menuItem.submenu = menu
        let index = windowMenuItem.flatMap { mainMenu.index(of: $0) } ?? mainMenu.items.count
        mainMenu.insertItem(menuItem, at: max(index, 0))
    }

    @objc private func newWorkspace(_ sender: Any?) {
        guard let controller = keyController else {
            guard let ghostty = (NSApp.delegate as? AppDelegate)?.ghostty else { return }
            _ = TerminalController.newWindow(ghostty)
            return
        }
        var config: Ghostty.SurfaceConfiguration? = nil
        if let surface = controller.focusedSurface?.surface {
            config = .init(from: ghostty_surface_inherited_config(surface, GHOSTTY_SURFACE_CONTEXT_WINDOW))
        }
        controller.newWorkspace(baseConfig: config)
    }
    @objc private func closeWorkspace(_ sender: Any?) { keyController?.closeWorkspace() }
    @objc private func renameWorkspace(_ sender: Any?) { keyController?.renameWorkspace() }
    @objc private func previousWorkspace(_ sender: Any?) { _ = keyController?.gotoWorkspace(GHOSTTY_GOTO_TAB_PREVIOUS) }
    @objc private func nextWorkspace(_ sender: Any?) { _ = keyController?.gotoWorkspace(GHOSTTY_GOTO_TAB_NEXT) }
}
