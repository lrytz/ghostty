import SwiftUI
import AppKit

/// AppKit hit target for tab strip items and sidebar rows: click selects
/// (or closes in the trailing `closeWidth`), middle-click closes, dragging
/// reorders among views of the same `kind`, right-click shows `menuItems`.
/// A tab released over another workspace's row, in any window, moves into
/// that workspace; a workspace released over another window moves there.
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
    /// Workspaces only: dropped on another window, before the row with the
    /// given ID or at the end.
    var onMoveToWindow: ((NSWindow, UUID?) -> Void)?

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
        v.onMoveToWindow = onMoveToWindow
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
        var onMoveToWindow: ((NSWindow, UUID?) -> Void)?

        /// Another window the dragged workspace would move to.
        private weak var dropWindow: NSWindow?

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
            guard let window else { return }
            let (targetWindow, target) = Self.hit(at: NSEvent.mouseLocation)

            guard targetWindow === window else {
                // Over another window, or none: no reordering, only moves.
                let row = target?.kind == .workspace ? target : nil
                switch kind {
                case .tab:
                    dropTarget = onMoveToWorkspace == nil ? nil : row
                    dropWindow = nil
                case .workspace:
                    let isTerminal = targetWindow?.windowController is TerminalController
                    dropWindow = onMoveToWindow != nil && isTerminal ? targetWindow : nil
                    dropTarget = dropWindow == nil ? nil : row
                }
                return
            }
            dropWindow = nil

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
            let target = dropTarget, targetWindow = dropWindow
            dropTarget = nil
            dropWindow = nil
            switch kind {
            case .tab:
                if let target { onMoveToWorkspace?(target.id) }
            case .workspace:
                if let targetWindow { onMoveToWindow?(targetWindow, target?.id) }
            }
        }

        /// The app's frontmost window at a screen point, and the item view
        /// under it. Other apps' windows in front hide ours.
        private static func hit(at screenPoint: NSPoint) -> (NSWindow?, MouseView?) {
            let number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0)
            guard let window = NSApp.window(withWindowNumber: number),
                  let content = window.contentView, let root = content.superview else { return (nil, nil) }
            let point = root.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
            return (window, content.hitTest(point) as? MouseView)
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
