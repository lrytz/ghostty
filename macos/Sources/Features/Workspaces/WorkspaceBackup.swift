import AppKit

/// Crash-safe mirror of the window restoration state. macOS only persists
/// restorable state on a clean quit, so a crash or kill loses all workspaces.
/// This JSON file is rewritten (debounced) on every change and used at launch
/// when the system has nothing to restore.
enum WorkspaceBackup {
    private struct File: Codable {
        let version: Int
        let windows: [WindowState]
    }

    private struct WindowState: Codable {
        let state: TerminalRestorableState.InternalState<Ghostty.SurfaceView>
        /// x, y, width, height
        let frame: [Double]?
    }

    private static let url: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.mitchellh.ghostty/workspaces-backup.json")

    private static var pending: DispatchWorkItem?

    /// Debounced save of all terminal windows.
    static func schedule() {
        pending?.cancel()
        let item = DispatchWorkItem { saveNow() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
    }

    static func saveNow() {
        pending?.cancel()
        pending = nil
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              appDelegate.ghostty.config.windowSaveState != "never" else { return }
        let windows: [WindowState] = TerminalController.all.map { c in
            .init(
                state: .init(from: c),
                frame: c.window.map { [$0.frame.origin.x, $0.frame.origin.y, $0.frame.width, $0.frame.height] })
        }
        do {
            let data = try JSONEncoder().encode(File(version: TerminalRestorableState.version, windows: windows))
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            AppDelegate.logger.error("workspace backup save failed: \(error)")
        }
    }

    /// Restore all windows from the backup. Returns whether any window was created.
    static func restore(_ ghostty: Ghostty.App) -> Bool {
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              appDelegate.ghostty.config.windowSaveState != "never" else { return false }
        guard let data = try? Data(contentsOf: url) else { return false }
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              file.version >= TerminalRestorableState.minimumVersion else {
            AppDelegate.logger.error("workspace backup exists but could not be decoded, ignoring")
            return false
        }
        var restored = false
        for win in file.windows {
            let c: TerminalController
            if let list = win.state.makeWorkspaceList() {
                c = TerminalController(ghostty, withWorkspaces: list)
            } else if win.state.surfaceTree.first != nil {
                c = TerminalController(ghostty, withSurfaceTree: win.state.surfaceTree)
            } else {
                continue
            }
            if let f = win.frame, f.count == 4, let window = c.window {
                window.setFrame(NSRect(x: f[0], y: f[1], width: f[2], height: f[3]), display: true)
            }
            c.showWindow(nil)
            restored = true
        }
        if restored {
            AppDelegate.logger.info("restored terminal windows from workspace backup")
        }
        return restored
    }
}
