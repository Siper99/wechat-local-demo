import SwiftUI
import SwiftData

/// 记录当前正在看的会话，模拟回复到达时据此决定要不要加未读
@MainActor
enum ChatPresence {
    static var visible: Set<UUID> = []
}

struct ChatView: View {
    @Bindable var conversation: Conversation

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("editMode") private var editMode = false
    @AppStorage("lastPasteChangeCount") private var lastPasteChangeCount = -1
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]

    @State private var draft = ""
    @State private var sendAsMe = true
    @State private var panel: InputPanel = .none
    @State private var editingMessage: Message?
    @State private var showSettings = false
    @State private var showSimulate = false
    @State private var peerTyping = false
    @State private var viewerImage: ViewerImage?
    @State private var showPasteHint = false
    @State private var pasteAsMe = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if showPasteHint { pasteHintBar }
            InputBar(draft: $draft, panel: $panel, sendAsMe: $sendAsMe,
                     inputFocused: $inputFocused, editMode: editMode,
                     onSend: send, onImages: sendImages, onSimulate: { showSimulate = true })
        }
        .background(Color.chatBackground.ignoresSafeArea())
        .navigationTitle(peerTyping ? "对方正在输入..." : conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "ellipsis") }
            }
        }
        .onAppear {
            ChatPresence.visible.insert(conversation.id)
            conversation.unread = 0
            checkPasteboard()
        }
        .onDisappear { ChatPresence.visible.remove(conversation.id) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                conversation.unread = 0
                checkPasteboard()
            }
        }
        .onChange(of: conversation.messages.count) { conversation.unread = 0 }
        .sheet(item: $editingMessage) { message in
            MessageEditSheet(message: message) { deleteFromSheet(message) }
        }
        .sheet(isPresented: $showSettings) { ConversationSettingsView(conversation: conversation) }
        .sheet(isPresented: $showSimulate) {
            SimulateReplySheet { text, delay in simulateReply(text: text, delay: delay) }
        }
        .fullScreenCover(item: $viewerImage) { ImageViewer(image: $0.image) }
    }

    // MARK: - 消息列表

    private var messageList: some View {
        let messages = conversation.sortedMessages
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || message.sentAt.timeIntervalSince(messages[index - 1].sentAt) > 300 {
                            Text(ChatTime.chatLabel(message.sentAt))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                        }
                        MessageRow(
                            message: message,
                            me: meList.first,
                            peer: conversation.peer,
                            editMode: editMode,
                            onEdit: { editingMessage = message },
                            onCopy: { copy(message) },
                            onRecall: { recall(message) },
                            onDelete: { delete(message) },
                            onToggleSender: { message.fromMe.toggle() },
                            onTapImage: { viewerImage = ViewerImage(image: $0) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                inputFocused = false
                withAnimation(.easeOut(duration: 0.2)) { panel = .none }
            })
            .onChange(of: messages.count) { scrollToBottom(proxy, messages) }
            .onChange(of: inputFocused) { _, focused in
                if focused {
                    panel = .none
                    scrollToBottom(proxy, messages, delay: 0.3)
                }
            }
            .onChange(of: panel) { _, newPanel in
                if newPanel != .none { scrollToBottom(proxy, messages, delay: 0.1) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, _ messages: [Message], delay: Double = 0) {
        guard let last = messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    // MARK: - 剪贴板提示条

    private var pasteHintBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard").foregroundStyle(Color.brand)
            Text("剪贴板有新内容").font(.system(size: 14))
            Spacer()
            Menu {
                Picker("发送方", selection: $pasteAsMe) {
                    Text("作为对方消息").tag(false)
                    Text("作为我的消息").tag(true)
                }
            } label: {
                HStack(spacing: 2) {
                    Text(pasteAsMe ? "作为我" : "作为对方")
                    Image(systemName: "chevron.down").font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            PasteButton(payloadType: String.self) { strings in
                Task { @MainActor in insertPasted(strings) }
            }
            .labelStyle(.titleOnly)
            .controlSize(.small)
            .buttonBorderShape(.capsule)
            .tint(Color.brand)
            Button {
                lastPasteChangeCount = UIPasteboard.general.changeCount
                withAnimation { showPasteHint = false }
            } label: {
                Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.inputBar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// hasStrings / changeCount 不会触发系统的"允许粘贴"弹窗
    private func checkPasteboard() {
        let pasteboard = UIPasteboard.general
        let fresh = pasteboard.hasStrings && pasteboard.changeCount != lastPasteChangeCount
        withAnimation { showPasteHint = fresh }
    }

    private func insertPasted(_ strings: [String]) {
        let text = strings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        lastPasteChangeCount = UIPasteboard.general.changeCount
        withAnimation { showPasteHint = false }
        guard !text.isEmpty else { return }
        context.addMessage(to: conversation, text: text, fromMe: pasteAsMe)
    }

    // MARK: - 动作

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.addMessage(to: conversation, text: text, fromMe: editMode ? sendAsMe : true)
        draft = ""
    }

    private func sendImages(_ images: [Data]) {
        let fromMe = editMode ? sendAsMe : true
        for (i, data) in images.enumerated() {
            context.addMessage(to: conversation, kind: .image, imageData: data, fromMe: fromMe,
                               at: Date().addingTimeInterval(Double(i) * 0.01))
        }
    }

    private func copy(_ message: Message) {
        UIPasteboard.general.string = message.text
        lastPasteChangeCount = UIPasteboard.general.changeCount
    }

    private func recall(_ message: Message) {
        message.kind = .system
        message.imageData = nil
        message.text = message.fromMe ? "你撤回了一条消息" : "\u{201C}\(conversation.title)\u{201D} 撤回了一条消息"
    }

    private func delete(_ message: Message) {
        context.delete(message)
        try? context.save()
    }

    private func deleteFromSheet(_ message: Message) {
        editingMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { delete(message) }
    }

    private func simulateReply(text: String, delay: Int) {
        let conversation = conversation
        let context = context
        Task { @MainActor in
            peerTyping = true
            try? await Task.sleep(for: .seconds(delay))
            peerTyping = false
            context.addMessage(to: conversation, text: text, fromMe: false)
            if !ChatPresence.visible.contains(conversation.id) {
                conversation.unread += 1
            }
            try? context.save()
        }
    }
}

struct ViewerImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
