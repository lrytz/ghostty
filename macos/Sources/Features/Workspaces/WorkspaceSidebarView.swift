import SwiftUI

/// Vertical list of this window's workspaces.
struct WorkspaceSidebarView: View {
    let controller: TerminalController
    /// Terminal background; the sidebar is tinted slightly off it.
    let background: Color
    @ObservedObject private var list: WorkspaceList

    static let width: CGFloat = 180

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
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(background)
        .background(Color.primary.opacity(0.06))
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
            ]))
    }
}
