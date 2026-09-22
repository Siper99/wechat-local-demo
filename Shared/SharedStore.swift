import Foundation
import SwiftData

enum AppGroup {
    /// 完整版由构建配置注入；个人版没有此键，直接使用本地数据库。
    static var id: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "QingLiaoAppGroup") as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    static var containerURL: URL? {
        guard let id else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}

enum SharedStore {
    static let schema = Schema([Contact.self, Conversation.self, Message.self])

    /// App 和分享扩展共用同一个数据库文件（放在 App Group 容器里）
    static func makeContainer() -> ModelContainer {
        let config: ModelConfiguration
        if let base = AppGroup.containerURL {
            config = ModelConfiguration(schema: schema, url: base.appending(path: "QingLiao.store"))
        } else {
            config = ModelConfiguration(schema: schema)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法打开数据库：\(error)")
        }
    }
}

/// 分享扩展不直接写数据库，而是把待导入内容写成文件放进 Inbox，
/// App 回到前台时统一读取入库，避免两个进程同时写 SwiftData。
struct PendingImport: Codable {
    var id = UUID()
    var conversationID: UUID?
    var newContactName: String?
    var fromMe: Bool
    var text: String?
    var imageFileNames: [String] = []
    var sentAt: Date
    var createdAt = Date()
}

enum Inbox {
    static var directory: URL? {
        guard let base = AppGroup.containerURL else { return nil }
        let dir = base.appending(path: "Inbox", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func write(_ item: PendingImport, images: [Data]) throws {
        guard let dir = directory else { throw CocoaError(.fileNoSuchFile) }
        var item = item
        for data in images {
            let name = UUID().uuidString + ".jpg"
            try data.write(to: dir.appending(path: name))
            item.imageFileNames.append(name)
        }
        // 图片先落盘，json 最后原子写入，App 只读 json，不会读到半截数据
        let json = try JSONEncoder().encode(item)
        try json.write(to: dir.appending(path: item.id.uuidString + ".json"), options: .atomic)
    }

    /// 返回导入的消息条数
    @MainActor
    static func drain(into context: ModelContext) -> Int {
        guard let dir = directory,
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return 0 }

        let decoder = JSONDecoder()
        let items: [(url: URL, item: PendingImport)] = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let item = try? decoder.decode(PendingImport.self, from: data) else { return nil }
                return (url, item)
            }
            .sorted { $0.item.createdAt < $1.item.createdAt }
        guard !items.isEmpty else { return 0 }

        let conversations = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        var inserted = 0

        for (url, item) in items {
            defer { try? FileManager.default.removeItem(at: url) }

            let conversation: Conversation
            if let id = item.conversationID, let found = conversations.first(where: { $0.id == id }) {
                conversation = found
            } else if let name = item.newContactName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                let contacts = (try? context.fetch(FetchDescriptor<Contact>())) ?? []
                let contact = contacts.first { $0.name == name && !$0.isMe } ?? {
                    let c = Contact(name: name)
                    context.insert(c)
                    return c
                }()
                conversation = context.conversation(with: contact)
            } else {
                item.imageFileNames.forEach { try? FileManager.default.removeItem(at: dir.appending(path: $0)) }
                continue
            }

            var time = item.sentAt
            var added = 0
            if let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                context.addMessage(to: conversation, text: text, fromMe: item.fromMe, at: time)
                added += 1
                time = time.addingTimeInterval(1)
            }
            for name in item.imageFileNames {
                let fileURL = dir.appending(path: name)
                if let data = try? Data(contentsOf: fileURL) {
                    context.addMessage(to: conversation, kind: .image, imageData: data, fromMe: item.fromMe, at: time)
                    added += 1
                    time = time.addingTimeInterval(1)
                }
                try? FileManager.default.removeItem(at: fileURL)
            }
            if !item.fromMe { conversation.unread += added }
            inserted += added
        }

        try? context.save()
        return inserted
    }
}
