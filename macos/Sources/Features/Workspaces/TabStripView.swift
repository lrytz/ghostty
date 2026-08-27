import SwiftUI
import AppKit

/// Horizontal tab strip for the active workspace, shown above the terminal.
struct TabStripView: View {
    let controller: TerminalController
    let background: Color
    @ObservedObject private var list: WorkspaceList

    static let height: CGFloat = 28

    init(controller: TerminalController, background: Color) {
        self.controller = controller
        self.background = background
        self.list = controller.workspaces
    }

    var body: some View {
        HStack(spacing: 0) {
            if let ws = list.active {
                TabStripContent(workspace: ws, controller: controller, background: background)
            }

            Button {
                controller.newTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: Self.height, height: Self.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.12))
        .background(background)
    }
}

private struct TabStripContent: View {
    @ObservedObject var workspace: Workspace
    let controller: TerminalController
    let background: Color

    var body: some View {
        ForEach(workspace.tabs) { tab in
            TabItem(tab: tab, isActive: tab === workspace.activeTab, background: background) {
                controller.activate(tab: tab, in: workspace)
            } onClose: {
                controller.closeTab(tab, in: workspace)
            } onReorder: { targetID in
                guard let target = workspace.tabs.first(where: { $0.id == targetID }),
                      let index = workspace.index(of: target) else { return }
                controller.move(tab: tab, to: index, in: workspace)
            }
        }
    }
}

private struct TabItem: View {
    @ObservedObject var tab: TerminalTab
    let isActive: Bool
    let background: Color
    let onSelect: () -> Void
    let onClose: () -> Void
    let onReorder: (UUID) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.callout)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: TabMouseView.closeWidth)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: TabStripView.height)
        .frame(minWidth: 80, maxWidth: 220)
        .foregroundStyle(isActive ? .primary : .secondary)
        .background(isActive ? background : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 1)
        }
        .overlay(TabMouseView(tabID: tab.id, onSelect: onSelect, onClose: onClose, onReorder: onReorder))
    }
}

/// AppKit hit target: clicks select (or close on the trailing "x"),
/// middle-click closes, dragging reorders. SwiftUI can't observe middle
/// clicks and its drag-and-drop is awkward for a tab strip.
private struct TabMouseView: NSViewRepresentable {
    static let closeWidth: CGFloat = 16
    let tabID: UUID
    let onSelect: () -> Void
    let onClose: () -> Void
    let onReorder: (UUID) -> Void

    func makeNSView(context: Context) -> MouseView {
        let v = MouseView()
        update(v)
        return v
    }

    func updateNSView(_ nsView: MouseView, context: Context) {
        update(nsView)
    }

    private func update(_ v: MouseView) {
        v.tabID = tabID
        v.onSelect = onSelect
        v.onClose = onClose
        v.onReorder = onReorder
    }

    final class MouseView: NSView {
        var tabID = UUID()
        var onSelect: () -> Void = {}
        var onClose: () -> Void = {}
        var onReorder: (UUID) -> Void = { _ in }

        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            if p.x >= bounds.maxX - closeWidth - 4 {
                onClose()
            } else {
                onSelect()
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let content = window.contentView, let root = content.superview else { return }
            let point = root.convert(event.locationInWindow, from: nil)
            guard let target = content.hitTest(point) as? MouseView, target !== self else { return }

            // Only swap once the pointer passed the target's center, so the
            // tabs don't flip back and forth at the boundary.
            let x = event.locationInWindow.x
            let mid = target.convert(NSPoint(x: target.bounds.midX, y: 0), to: nil).x
            let selfX = convert(NSPoint(x: bounds.midX, y: 0), to: nil).x
            if (selfX < mid && x > mid) || (selfX > mid && x < mid) {
                onReorder(target.tabID)
            }
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else { return }
            onClose()
        }
    }
}
