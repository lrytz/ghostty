import SwiftUI
import AppKit

/// AppKit hit target for tab strip items and sidebar rows: click selects
/// (or closes in the trailing `closeWidth`), middle-click closes, dragging
/// reorders among views of the same `kind`, right-click shows `menuItems`.
/// A tab released over another workspace's row moves into that workspace.
/// SwiftUI can't observe middle clicks and its drag-and-drop is awkward
/// for a strip; an NSView overlay also swallows right-clicks, hence the
/// AppKit menu.
struct ReorderMouseView: NSViewRepresentable {
    enum Kind { case tab, workspace }

    let kind: Kind
    let id: UUID
    var closeWidth: CGFloat = 0
    let onSelect: () -> Void
    let onClose: () -> Void
    let onReorder: (UUID) -> Void
    var menuItems: [(title: String, action: () -> Void)] = []
    /// Tabs only: the tab's own workspace, which is not a drop target.
    var workspaceID: UUID?
    var onMoveToWorkspace: ((UUID) -> Void)?

    func makeNSView(context: Context) -> MouseView {
        let v = MouseView()
        update(v)
        return v
    }

    func updateNSView(_ nsView: MouseView, context: Context) {
        update(nsView)
    }

    private func update(_ v: MouseView) {
        v.kind = kind
        v.id = id
        v.closeWidth = closeWidth
        v.onSelect = onSelect
        v.onClose = onClose
        v.onReorder = onReorder
        v.menuItems = menuItems
        v.workspaceID = workspaceID
        v.onMoveToWorkspace = onMoveToWorkspace
    }

    final class MouseView: NSView {
        var kind: Kind = .tab
        var id = UUID()
        var closeWidth: CGFloat = 0
        var onSelect: () -> Void = {}
        var onClose: () -> Void = {}
        var onReorder: (UUID) -> Void = { _ in }
        var menuItems: [(title: String, action: () -> Void)] = []
        var workspaceID: UUID?
        var onMoveToWorkspace: ((UUID) -> Void)?

        private weak var dropTarget: MouseView? {
            didSet {
                guard oldValue !== dropTarget else { return }
                oldValue?.setHighlighted(false)
                dropTarget?.setHighlighted(true)
            }
        }

        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            if closeWidth > 0, p.x >= bounds.maxX - closeWidth - 4 {
                onClose()
            } else {
                onSelect()
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let content = window.contentView, let root = content.superview else { return }
            let point = root.convert(event.locationInWindow, from: nil)
            let target = content.hitTest(point) as? MouseView

            if kind == .tab, onMoveToWorkspace != nil,
               let target, target.kind == .workspace, target.id != workspaceID {
                dropTarget = target
            } else {
                dropTarget = nil
            }

            guard let target, target !== self, target.kind == kind else { return }

            // Only swap once the pointer passed the target's center, so the
            // items don't flip back and forth at the boundary.
            let pos = coord(event.locationInWindow)
            let mid = coord(target.convert(target.center, to: nil))
            let selfPos = coord(convert(center, to: nil))
            if (selfPos < mid && pos > mid) || (selfPos > mid && pos < mid) {
                onReorder(target.id)
            }
        }

        override func mouseUp(with event: NSEvent) {
            guard let target = dropTarget else { return }
            dropTarget = nil
            onMoveToWorkspace?(target.id)
        }

        private func setHighlighted(_ on: Bool) {
            wantsLayer = true
            layer?.cornerRadius = 5
            layer?.backgroundColor = on ? NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor : nil
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else { return }
            onClose()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard !menuItems.isEmpty else { return nil }
            let menu = NSMenu()
            for item in menuItems {
                menu.addItem(ClosureMenuItem(title: item.title, action: item.action))
            }
            return menu
        }

        private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }

        private func coord(_ p: NSPoint) -> CGFloat {
            kind == .tab ? p.x : p.y
        }
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func fire() { handler() }
}
