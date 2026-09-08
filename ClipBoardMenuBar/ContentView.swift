import SwiftUI
import AppKit
import Combine

enum FilterType: String, CaseIterable {
    case all = "Все"
    case text = "Текст"
    case image = "Фото"
    case link = "Ссылки"
}

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
    @State private var filter: FilterType = .all

    private var filteredItems: [ClipboardItem] {
        switch filter {
        case .all: return manager.items
        case .text: return manager.items.filter { $0.type == .text }
        case .image: return manager.items.filter { $0.type == .image }
        case .link: return manager.items.filter { $0.type == .url }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $filter) {
                ForEach(FilterType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            if filteredItems.isEmpty {
                Text("История пуста")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 30)
            } else {
                List(filteredItems) { item in
                    Text(item.text ?? "Изображение")
                        .lineLimit(2)
                        .onTapGesture {
                            manager.copyToPasteboard(item)
                        }
                }
                .listStyle(.plain)
                .frame(height: 300)
            }
        }
        .frame(width: 310)
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

    func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount + 1

        switch item.type {
        case .text, .url:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let tiff = item.image?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
    }

    func clear() {
        items.removeAll()
    }
}
