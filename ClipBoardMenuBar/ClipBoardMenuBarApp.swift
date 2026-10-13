import SwiftUI
import AppKit

@main
struct ClipBoardMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let manager = PasteboardManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 310, height: 340)
        popover.contentViewController = NSHostingController(rootView: ContentView(manager: manager))
        popover.contentViewController?.view.frame.size = NSSize(width: 310, height: 340)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Очистить", action: #selector(clearHistory), keyEquivalent: "")
        menu.items.last?.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выход", action: #selector(quit), keyEquivalent: "")
        menu.items.last?.target = self

        if let button = statusItem.button {
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: button)
        }
    }
    
    @objc private func clearHistory() {
        manager.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
