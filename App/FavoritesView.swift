import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(filter: #Predicate<Message> { $0.isFavorite == true }, sort: \Message.sentAt, order: .reverse)
    private var favorites: [Message]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(favorites) { message in
                VStack(alignment: .leading, spacing: 12) {
                    if message.kind == .image, let image = ImageCache.image(for: message.id, data: message.imageData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    } else {
                        Text(message.text).font(.system(size: 17))
                    }
                    Text("\(message.fromMe ? "我" : message.conversation?.title ?? "联系人")  ·  \(ChatTime.chatLabel(message.sentAt))")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .swipeActions {
                    Button("取消收藏", role: .destructive) {
                        message.isFavorite = false
                        try? context.save()
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "cube", description: Text("长按聊天消息，选择收藏"))
            }
        }
        .navigationTitle("我的收藏")
        .weChatNavigation()
    }
}

struct ChatHistoryView: View {
    let conversation: Conversation
    @State private var search = ""
    var body: some View {
        VStack(spacing: 0) {
            WeChatSearchBar(text: $search)
            List {
                ForEach(conversation.sortedMessages.filter { search.isEmpty || $0.text.localizedStandardContains(search) }) { message in
                    HStack(alignment: .top, spacing: 12) {
                        AvatarView(contact: message.fromMe ? nil : conversation.peer, size: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.fromMe ? "我" : conversation.title).font(.system(size: 15))
                                Spacer()
                                Text(ChatTime.listLabel(message.sentAt)).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Text(message.preview).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
            }.listStyle(.plain)
        }
        .navigationTitle("查找聊天记录")
        .weChatNavigation()
    }
}
