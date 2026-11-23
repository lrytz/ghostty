import SwiftUI
import AppKit

/// Vertical list of this window's workspaces.
struct WorkspaceSidebarView: View {
    let controller: TerminalController
    /// Terminal background; the sidebar is tinted slightly off it.
    let background: Color
    @ObservedObject private var list: WorkspaceList

    static let defaultWidth: CGFloat = 180
    static let widthRange: ClosedRange<CGFloat> = 120...480

    @AppStorage("WorkspaceSidebarWidth") private var width: Double = defaultWidth

    init(controller: TerminalController, background: Color) {
        self.controller = controller
        self.background = background
        self.list = controller.workspaces
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(list.workspaces.enumerated()), id: \.element.id) { index, ws in
                WorkspaceRow(workspace: ws, controller: controller, index: index + 1, isActive: ws === list.active) { targetID in
                    guard let target = list.workspaces.first(where: { $0.id == targetID }),
                          let index = list.index(of: target) else { return }
                    controller.move(workspace: ws, to: index)
                }
            }

            Spacer()

            Button {
                controller.newWorkspace()
            } label: {
                Label("New Workspace", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .padding(6)
        .frame(width: Self.widthRange.clamp(width))
        .frame(maxHeight: .infinity)
        .background(background)
        .background(Color.primary.opacity(0.06))
        .overlay(alignment: .trailing) {
            SidebarResizeHandle(
                width: { Self.widthRange.clamp(width) },
                setWidth: { width = Self.widthRange.clamp($0) },
                reset: { width = Self.defaultWidth })
                .frame(width: 5)
        }
    }
}

private extension ClosedRange where Bound == CGFloat {
    func clamp(_ v: CGFloat) -> CGFloat { Swift.min(Swift.max(v, lowerBound), upperBound) }
}

/// Drag strip on the sidebar's trailing edge; double-click restores the
/// default width. AppKit so the resize cursor sticks and window dragging
/// doesn't steal the mouse.
private struct SidebarResizeHandle: NSViewRepresentable {
    let width: () -> CGFloat
    let setWidth: (CGFloat) -> Void
    let reset: () -> Void

    func makeNSView(context: Context) -> HandleView { update(HandleView()) }
    func updateNSView(_ v: HandleView, context: Context) { _ = update(v) }

    private func update(_ v: HandleView) -> HandleView {
        v.width = width
        v.setWidth = setWidth
        v.reset = reset
        return v
    }

    final class HandleView: NSView {
        var width: () -> CGFloat = { 0 }
        var setWidth: (CGFloat) -> Void = { _ in }
        var reset: () -> Void = {}
        private var start: (x: CGFloat, width: CGFloat)?

        override var mouseDownCanMoveWindow: Bool { false }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                reset()
                start = nil
                return
            }
            start = (event.locationInWindow.x, width())
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start else { return }
            NSCursor.resizeLeftRight.set()
            setWidth(start.width + event.locationInWindow.x - start.x)
        }

        override func mouseUp(with event: NSEvent) {
            start = nil
        }
    }
}

private struct WorkspaceRow: View {
    @ObservedObject var workspace: Workspace
    let controller: TerminalController
    let index: Int
    let isActive: Bool
    let onReorder: (UUID) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .trailing)
            Text(workspace.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if workspace.hasBell {
                BellDot()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(ReorderMouseView(
            kind: .workspace, id: workspace.id,
            onSelect: { controller.activate(workspace: workspace) },
            onClose: { controller.closeWorkspace(workspace) },
            onReorder: onReorder,
            menuItems: [
                ("Rename…", { controller.renameWorkspace(workspace) }),
                ("Close", { controller.closeWorkspace(workspace) }),
            ],
            onMoveToWindow: { window, beforeID in
                guard let dst = window.windowController as? TerminalController else { return }
                let before = dst.workspaces.workspaces.first { $0.id == beforeID }
                dst.adopt(workspace: workspace, from: controller, before: before)
            }))
    }
}
