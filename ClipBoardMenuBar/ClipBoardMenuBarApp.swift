import SwiftUI

@main
struct ClipBoardMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("ClipBoardMenuBar", systemImage: "doc.on.clipboard") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
