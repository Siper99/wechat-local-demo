import Foundation
import SwiftData

@Model
final class Contact {
    var id: UUID = UUID()
    var name: String = ""
    @Attribute(.externalStorage) var avatarData: Data?
    var isMe: Bool = false
    /// 文件传输助手等内置会话，不出现在通讯录字母列表
    var isSystem: Bool = false
    /// 朋友权限：仅聊天（不看对方朋友圈、对方也看不到我的）
    var chatOnly: Bool = false
    var tags: [String] = []
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Conversation.peer)
    var conversations: [Conversation] = []
    /// 所在群聊（反向关系由 Conversation.members 声明）
    var groups: [Conversation] = []

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
    var draft: String = ""
    var createdAt: Date = Date()
    var isGroup: Bool = false
    var groupName: String = ""
    @Relationship(deleteRule: .nullify, inverse: \Contact.groups)
    var members: [Contact] = []

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init() {}

    var title: String {
        guard isGroup else { return peer?.name ?? "未命名" }
        if !groupName.isEmpty { return groupName }
        let names = members.map(\.name).sorted().prefix(4).joined(separator: "、")
        return names.isEmpty ? "群聊" : names
    }
    /// 群聊标题带人数（含自己），如"周末爬山(4)"
    var displayTitle: String { isGroup ? "\(title)(\(members.count + 1))" : title }
    var sortedMessages: [Message] { messages.sorted { $0.sentAt < $1.sentAt } }
    var lastMessage: Message? { messages.max { $0.sentAt < $1.sentAt } }
    var lastActivity: Date { lastMessage?.sentAt ?? createdAt }
}

enum MessageKind: String, Codable {
    case text, image, system, location, voice, card, call
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
    var quotedText: String? = nil
    var quotedSender: String? = nil
    var isFavorite: Bool = false
    var locationAddress: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// 群聊中对方消息的发送者
    var senderID: UUID? = nil
    var senderName: String? = nil
    @Attribute(.externalStorage) var audioData: Data?
    var duration: Double = 0
    /// 名片消息引用的联系人
    var cardContactID: UUID? = nil
    var isVideoCall: Bool = false

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
        case .location: return "[位置] " + text
        case .voice: return "[语音]"
        case .card: return "[个人名片] " + text
        case .call: return isVideoCall ? "[视频通话]" : "[语音通话]"
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

// MARK: - 朋友圈

@Model
final class Moment {
    var id: UUID = UUID()
    var authorID: UUID?
    var authorName: String = ""
    var text: String = ""
    var location: String = ""
    var createdAt: Date = Date()
    /// 其他人的点赞（昵称），"我"的点赞单独记录
    var likes: [String] = []
    var likedByMe: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \MomentPhoto.moment)
    var photos: [MomentPhoto] = []
    @Relationship(deleteRule: .cascade, inverse: \MomentComment.moment)
    var comments: [MomentComment] = []

    init(author: Contact?, text: String, createdAt: Date = .now) {
        self.authorID = author?.id
        self.authorName = author?.name ?? ""
        self.text = text
        self.createdAt = createdAt
    }

    var sortedPhotos: [MomentPhoto] { photos.sorted { $0.index < $1.index } }
    var sortedComments: [MomentComment] { comments.sorted { $0.createdAt < $1.createdAt } }
}

@Model
final class MomentPhoto {
    var id: UUID = UUID()
    var index: Int = 0
    @Attribute(.externalStorage) var data: Data?
    var moment: Moment?

    init(index: Int, data: Data?) {
        self.index = index
        self.data = data
    }
}

@Model
final class MomentComment {
    var id: UUID = UUID()
    var authorName: String = ""
    var fromMe: Bool = false
    var replyTo: String? = nil
    var text: String = ""
    var createdAt: Date = Date()
    var moment: Moment?

    init(authorName: String, fromMe: Bool, text: String, replyTo: String? = nil) {
        self.authorName = authorName
        self.fromMe = fromMe
        self.text = text
        self.replyTo = replyTo
    }
}

// MARK: - 我 / 发现 / 通讯录 的本地功能数据

/// 收藏里的笔记，也用于小程序"记事本"
@Model
final class Note {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(text: String) { self.text = text }
}

/// 收藏的表情
@Model
final class Sticker {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    var createdAt: Date = Date()
    init(data: Data?) { self.data = data }
}

/// 卡包：会员卡 / 优惠券 / 票券（只存名称和备注，不保存卡号）
@Model
final class WalletCard {
    var id: UUID = UUID()
    var kindRaw: String = "会员卡"
    var title: String = ""
    var note: String = ""
    var colorHex: Int = 0x07C160
    var createdAt: Date = Date()
    init(kind: String, title: String, note: String, colorHex: Int) {
        self.kindRaw = kind
        self.title = title
        self.note = note
        self.colorHex = colorHex
    }
}

/// 公众号 / 服务号
@Model
final class OfficialAccount {
    var id: UUID = UUID()
    var name: String = ""
    var intro: String = ""
    var isService: Bool = false
    var colorHex: Int = 0x1485EE
    var symbol: String = "book.fill"
    @Relationship(deleteRule: .cascade, inverse: \Article.account)
    var articles: [Article] = []
    init(name: String, intro: String, isService: Bool, colorHex: Int, symbol: String) {
        self.name = name
        self.intro = intro
        self.isService = isService
        self.colorHex = colorHex
        self.symbol = symbol
    }
}

@Model
final class Article {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var publishedAt: Date = Date()
    var liked: Bool = false
    var watching: Bool = false
    var account: OfficialAccount?
    init(title: String, body: String, publishedAt: Date) {
        self.title = title
        self.body = body
        self.publishedAt = publishedAt
    }
}

/// 视频号：从相册导入的本地视频
@Model
final class ChannelVideo {
    var id: UUID = UUID()
    var fileName: String = ""
    var caption: String = ""
    var liked: Bool = false
    var createdAt: Date = Date()
    init(fileName: String, caption: String) {
        self.fileName = fileName
        self.caption = caption
    }
}

/// 听一听：从"文件"导入的本地音频
@Model
final class AudioTrack {
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String = ""
    var duration: Double = 0
    var addedAt: Date = Date()
    init(title: String, fileName: String, duration: Double) {
        self.title = title
        self.fileName = fileName
        self.duration = duration
    }
}

/// 小程序：自定义网页入口
@Model
final class MiniApp {
    var id: UUID = UUID()
    var name: String = ""
    var urlString: String = ""
    var lastUsed: Date = Date()
    init(name: String, urlString: String) {
        self.name = name
        self.urlString = urlString
    }
}

/// 新的朋友：好友申请
@Model
final class FriendRequest {
    var id: UUID = UUID()
    var name: String = ""
    var greeting: String = ""
    var accepted: Bool = false
    var createdAt: Date = Date()
    init(name: String, greeting: String) {
        self.name = name
        self.greeting = greeting
    }
}

/// 本地文件目录（视频号、听一听、聊天背景、朋友圈封面）
enum LocalFiles {
    static func directory(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appending(path: name, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var chatBackground: URL { directory("Appearance").appending(path: "chat_background.jpg") }
    static var momentsCover: URL { directory("Appearance").appending(path: "moments_cover.jpg") }
}
