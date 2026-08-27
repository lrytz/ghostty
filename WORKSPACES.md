# Workspaces fork

macOS-only fork adding cmux-style workspaces to Ghostty. Not intended for upstream.

## Model

Native `NSWindow` tabs are disabled (`tabbingMode = .disallowed`). One real
window holds:

```
TerminalController (1 NSWindow)
└─ WorkspaceList          workspaces, active
   └─ Workspace           name, tabs, activeTab
      └─ TerminalTab      surfaceTree (splits), focusedSurface, titleOverride
```

Only the active tab's tree is mounted as `TerminalController.surfaceTree`;
the controller writes tree/focus/title changes back to the active tab
(`surfaceTreeDidChange`, `focusedSurfaceDidChange`, `titleOverride`).
Switching tabs swaps the mounted tree; unmounted surfaces are marked
unfocused and occluded but keep running.

Code: `macos/Sources/Features/Workspaces/` (model, sidebar, tab strip,
Workspace menu) and `macos/Sources/Features/Terminal/TerminalController.swift`.
Window restoration encodes all workspaces (state version 8).

## Actions

Keybind actions (Zig core): `new_workspace`, `close_workspace`,
`rename_workspace`, `previous_workspace`, `next_workspace`, `goto_workspace:N`.
Defaults: `cmd+ctrl+n/w/r`, `cmd+ctrl+alt+up/down`. Existing tab actions
(`new_tab`, `close_tab`, `goto_tab`, `move_tab`, ...) operate on the model.

Tab strip: click selects, `x` or middle click closes, `+` adds, drag reorders. Sidebar rows:
click switches, right-click renames/closes. Undo (`undo` action) restores a
closed tab, workspace or window.

## Not implemented

Tab colors, macOS tab overview, move-tab-to-new-window,
sidebar hide option, tabs listed under workspaces.

## Building

```
zig build                      # needs Xcode + Metal toolchain
pkill -x ghostty; open zig-out/Ghostty.app
```

Overwriting the bundle while it runs invalidates the code signature; fix with
`codesign --force --deep -s - zig-out/Ghostty.app`. `zig build` hides Swift
errors; see them with
`cd macos && xcodebuild -project Ghostty.xcodeproj -scheme Ghostty -configuration Debug -arch arm64 build 2>&1 | grep error`.
