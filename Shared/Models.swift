import Foundation
import SwiftData

@Model
final class Contact {
    var id: UUID = UUID()
    var name: String = ""
    @Attribute(.externalStorage) var avatarData: Data?
    var isMe: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Conversation.peer)
    var conversations: [Conversation] = []

    init(name: String, avatarData: Data? = nil, isMe: Bool = false) {
        self.name = name
        self.avatarData = avatarData
        self.isMe = isMe
    }

    /// 展示用的"微信号"
    var handle: String {
        isMe ? "wxid_me" : "wxid_" + id.uuidString.prefix(8).lowercased()
    }
}

@Model
final class Conversation {
    var id: UUID = UUID()
    var peer: Contact?
    var pinned: Bool = false
    var muted: Bool = false
    var unread: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init() {}

    var title: String { peer?.name ?? "未命名" }
    var sortedMessages: [Message] { messages.sorted { $0.sentAt < $1.sentAt } }
    var lastMessage: Message? { messages.max { $0.sentAt < $1.sentAt } }
    var lastActivity: Date { lastMessage?.sentAt ?? createdAt }
}

enum MessageKind: String, Codable {
    case text, image, system
}

@Model
final class Message {
    var id: UUID = UUID()
    var conversation: Conversation?
    var fromMe: Bool = false
    var kindRaw: String = MessageKind.text.rawValue
    var text: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var sentAt: Date = Date()

    init(kind: MessageKind = .text, text: String = "", imageData: Data? = nil, fromMe: Bool, sentAt: Date = .now) {
        self.kindRaw = kind.rawValue
        self.text = text
        self.imageData = imageData
        self.fromMe = fromMe
        self.sentAt = sentAt
    }

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var preview: String {
        switch kind {
        case .text, .system: return text
        case .image: return "[图片]"
        }
    }
}

extension ModelContext {
    func me() -> Contact {
        let descriptor = FetchDescriptor<Contact>(predicate: #Predicate { $0.isMe == true })
        if let me = try? fetch(descriptor).first { return me }
        let me = Contact(name: "我", isMe: true)
        insert(me)
        return me
    }

    func conversation(with contact: Contact) -> Conversation {
        if let existing = contact.conversations.first { return existing }
        let conversation = Conversation()
        insert(conversation)
        conversation.peer = contact
        return conversation
    }

    @discardableResult
    func addMessage(to conversation: Conversation, kind: MessageKind = .text, text: String = "",
                    imageData: Data? = nil, fromMe: Bool, at date: Date = .now) -> Message {
        let message = Message(kind: kind, text: text, imageData: imageData, fromMe: fromMe, sentAt: date)
        insert(message)
        message.conversation = conversation
        return message
    }
}
