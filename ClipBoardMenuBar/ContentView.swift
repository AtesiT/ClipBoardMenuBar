import SwiftUI
import AppKit

enum ClipboardItemType {
    case text, url, image
}

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let type: ClipboardItemType
    var text: String?
    var image: NSImage?
    var url: URL?
    let timestamp: Date

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    var body: some View {
        Text("ClipBoardMenuBar")
            .frame(width: 310, height: 100)
    }
}
