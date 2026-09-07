import SwiftUI
import AppKit
import Combine

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
    @StateObject private var manager = PasteboardManager()

    var body: some View {
        Text("ClipBoardMenuBar")
            .frame(width: 310, height: 100)
    }
}

final class PasteboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []

    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    deinit {
        timer?.invalidate()
    }
    
    private func add(_ item: ClipboardItem) {
        if let last = items.first, last.type == item.type,
           last.text == item.text,
           last.image?.tiffRepresentation == item.image?.tiffRepresentation {
            return
        }
        items.insert(item, at: 0)
        if items.count > 30 {
            items.removeLast()
        }
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let data = pasteboard.data(forType: .tiff), let image = NSImage(data: data) {
            add(ClipboardItem(type: .image, image: image, timestamp: Date()))
        } else if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if let url = URL(string: trimmed), url.scheme != nil, trimmed.contains(".") {
                add(ClipboardItem(type: .url, text: trimmed, url: url, timestamp: Date()))
            } else {
                add(ClipboardItem(type: .text, text: trimmed, timestamp: Date()))
            }
        }
    }
}

