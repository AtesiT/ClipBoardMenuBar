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
        popover.contentSize = NSSize(width: 310, height: 380)
        popover.contentViewController = NSHostingController(rootView: ContentView(manager: manager))
    }

    @objc private func handleClick() {
        print("HandleClick")
    }

    private func togglePopover() {
        print("TogglePopover")
    }

    private func showContextMenu() {
        let menu = NSMenu()
        //  TODO: Меню сделать
    }

    @objc private func clearHistory() {
        manager.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
