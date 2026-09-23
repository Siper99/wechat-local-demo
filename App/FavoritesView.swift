import SwiftUI
import SwiftData

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
