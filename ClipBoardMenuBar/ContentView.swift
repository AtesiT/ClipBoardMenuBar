import SwiftUI
import AppKit
import ImageIO
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
    var thumbnail: NSImage?
    var rawImageData: Data?
    var url: URL?
    let timestamp: Date

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text(item.text ?? "")
                    .lineLimit(2)
                    .font(.system(size: 13))

            case .url:
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text(item.text ?? "")
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(.blue)

            case .image:
                if let thumbnail = item.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("Изображение")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ContentView: View {
    @ObservedObject var manager: PasteboardManager
    var onCopy: (() -> Void)? = nil
    @State private var filter: FilterType = .all
    @State private var showToast = false
    
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

            Group {
                if filteredItems.isEmpty {
                    VStack {
                        Spacer()
                        Text("История пуста")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredItems) { item in
                        ClipboardRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { copy(item) }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(height: 300)
        }
        .frame(width: 310)
        .overlay(alignment: .top) {
            if showToast {
                Text("Скопировано")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        manager.copyToPasteboard(item)
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onCopy?()
        }
    }
}

final class PasteboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []

    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    init() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit {
        timer?.invalidate()
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let thumb = Self.makeThumbnail(from: data, maxPixelSize: 128)
                DispatchQueue.main.async {
                    self?.add(ClipboardItem(type: .image, thumbnail: thumb, rawImageData: data, timestamp: Date()))
                }
            }
        } else if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if let detector = Self.linkDetector,
               let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               match.range.length == trimmed.utf16.count,
               let url = match.url {
                add(ClipboardItem(type: .url, text: trimmed, url: url, timestamp: Date()))
            } else {
                add(ClipboardItem(type: .text, text: trimmed, timestamp: Date()))
            }
        }
    }

    private static func makeThumbnail(from data: Data, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func add(_ item: ClipboardItem) {
        if let last = items.first, last.type == item.type,
           last.text == item.text,
           last.rawImageData == item.rawImageData {
            return
        }
        items.insert(item, at: 0)
        while items.count > 30 {
            items.removeLast()
        }
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .url:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.rawImageData {
                pasteboard.setData(data, forType: .tiff)
            }
        }

        lastChangeCount = pasteboard.changeCount
    }

    func clear() {
        items.removeAll()
    }
}
