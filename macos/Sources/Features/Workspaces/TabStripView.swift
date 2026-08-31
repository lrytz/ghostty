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
    static let closeWidth: CGFloat = 16

    @ObservedObject var tab: TerminalTab
    let isActive: Bool
    let background: Color
    let onSelect: () -> Void
    let onClose: () -> Void
    let onReorder: (UUID) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if tab.hasBell {
                BellDot()
            }
            Text(tab.displayTitle)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.callout)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: TabItem.closeWidth)
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
        .overlay(ReorderMouseView(
            kind: .tab, id: tab.id, closeWidth: Self.closeWidth,
            onSelect: onSelect, onClose: onClose, onReorder: onReorder))
    }
}

/// Indicator that a background tab or workspace rang the bell (e.g. an AI
/// agent finished and wants attention).
struct BellDot: View {
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 7, height: 7)
    }
}
