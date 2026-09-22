import SwiftUI
import SwiftData

@main
struct QingLiaoApp: App {
    let container = SharedStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var conversations: [Conversation]
    @State private var toast: String?

    private var unreadTotal: Int {
        conversations.filter { !$0.muted }.reduce(0) { $0 + $1.unread }
    }

    var body: some View {
        TabView {
            ConversationListView()
                .tabItem { Label("微信", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(unreadTotal)
            ContactsView()
                .tabItem { Label("通讯录", systemImage: "person.2.fill") }
            DiscoverView()
                .tabItem { Label("发现", systemImage: "safari.fill") }
            MeView()
                .tabItem { Label("我", systemImage: "person.fill") }
        }
        .tint(Color.brand)
        .task {
            SeedData.seedIfNeeded(context)
            ingestInbox()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: ingestInbox()
            case .background: try? context.save()
            default: break
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.75)))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func ingestInbox() {
        let count = Inbox.drain(into: context)
        guard count > 0 else { return }
        withAnimation { toast = "已导入 \(count) 条消息" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }
}
