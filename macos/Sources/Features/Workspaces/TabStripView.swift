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
        .overlay(TabMouseView(onSelect: onSelect, onClose: onClose))
    }
}

/// AppKit hit target so middle-click closes and clicks on the trailing "x"
/// close; SwiftUI can't observe middle clicks.
private struct TabMouseView: NSViewRepresentable {
    static let closeWidth: CGFloat = 16
    let onSelect: () -> Void
    let onClose: () -> Void

    func makeNSView(context: Context) -> MouseView {
        let v = MouseView()
        v.onSelect = onSelect
        v.onClose = onClose
        return v
    }

    func updateNSView(_ nsView: MouseView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onClose = onClose
    }

    final class MouseView: NSView {
        var onSelect: () -> Void = {}
        var onClose: () -> Void = {}

        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            if p.x >= bounds.maxX - closeWidth - 4 {
                onClose()
            } else {
                onSelect()
            }
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else { return }
            onClose()
        }
    }
}
