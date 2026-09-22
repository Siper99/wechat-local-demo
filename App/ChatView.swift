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
    @State private var quotedMessage: Message?
    @State private var forwardMessages: [Message] = []
    @State private var showForward = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmDeleteSelection = false
    @State private var toast: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if isSelecting {
                selectionBar
            } else {
                if showPasteHint && editMode { pasteHintBar }
                if let quote = quotedMessage {
                    HStack {
                        Text("\(quote.fromMe ? "我" : conversation.title)：\(quote.preview)")
                            .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        Button { quotedMessage = nil } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("取消引用")
                    }
                    .padding(12).background(Color.inputBar)
                }
                InputBar(draft: $draft, panel: $panel, sendAsMe: $sendAsMe,
                     inputFocused: $inputFocused, editMode: editMode,
                     onSend: send, onImages: sendImages, onSimulate: { showSimulate = true })
            }
        }
        .background(Color.chatBackground.ignoresSafeArea())
        .navigationTitle(isSelecting ? "已选择 \(selectedIDs.count) 条" : peerTyping ? "对方正在输入..." : conversation.title)
        .weChatNavigation()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("取消") { isSelecting = false; selectedIDs.removeAll() }
                } else {
                    Button { showSettings = true } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("聊天信息")
                }
            }
        }
        .onAppear {
            if draft.isEmpty { draft = conversation.draft }
            ChatPresence.visible.insert(conversation.id)
            conversation.unread = 0
            checkPasteboard()
        }
        .onChange(of: draft) { _, value in conversation.draft = value }
        .onDisappear {
            ChatPresence.visible.remove(conversation.id)
            try? context.save()
        }
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
        .navigationDestination(isPresented: $showSettings) { ConversationSettingsView(conversation: conversation) }
        .sheet(isPresented: $showSimulate) {
            SimulateReplySheet { text, delay in simulateReply(text: text, delay: delay) }
        }
        .fullScreenCover(item: $viewerImage) { ImageViewer(image: $0.image) }
        .sheet(isPresented: $showForward) {
            NewChatView { target in forward(to: target) }
        }
        .confirmationDialog("删除选中的 \(selectedIDs.count) 条消息？", isPresented: $confirmDeleteSelection, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                conversation.messages.filter { selectedIDs.contains($0.id) }.forEach { context.delete($0) }
                try? context.save()
                isSelecting = false
                selectedIDs.removeAll()
            }
        }
        .overlay(alignment: .center) {
            if let toast {
                Text(toast).font(.system(size: 15)).foregroundStyle(.white)
                    .padding(20).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
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
                        HStack(spacing: 8) {
                            if isSelecting {
                                Image(systemName: selectedIDs.contains(message.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 23))
                                    .foregroundStyle(selectedIDs.contains(message.id) ? Color.brand : Color.secondary)
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
                            onTapImage: { viewerImage = ViewerImage(image: $0) },
                            onForward: { forwardMessages = [message]; showForward = true },
                            onQuote: { quotedMessage = message; panel = .none; inputFocused = true },
                            onFavorite: { message.isFavorite.toggle(); try? context.save(); showToast(message.isFavorite ? "已收藏" : "已取消收藏") },
                            onSelect: { inputFocused = false; panel = .none; isSelecting = true; selectedIDs = [message.id] }
                        )
                            .allowsHitTesting(!isSelecting)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelecting {
                                if selectedIDs.contains(message.id) { selectedIDs.remove(message.id) }
                                else { selectedIDs.insert(message.id) }
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .onAppear { scrollToBottom(proxy, messages) }
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
        let message = context.addMessage(to: conversation, text: text, fromMe: editMode ? sendAsMe : true)
        message.quotedText = quotedMessage?.preview
        message.quotedSender = quotedMessage.map { $0.fromMe ? "我" : conversation.title }
        quotedMessage = nil
        try? context.save()
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

    private var selectionBar: some View {
        HStack {
            Button {
                forwardMessages = conversation.sortedMessages.filter { selectedIDs.contains($0.id) }
                showForward = true
            } label: { Label("转发", systemImage: "arrowshape.turn.up.right").frame(maxWidth: .infinity) }
            Button(role: .destructive) { confirmDeleteSelection = true } label: {
                Label("删除", systemImage: "trash").frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 17))
        .disabled(selectedIDs.isEmpty)
        .padding(.vertical, 18)
        .background(Color.inputBar.ignoresSafeArea(edges: .bottom))
    }

    private func forward(to target: Conversation) {
        for message in forwardMessages {
            let copy = context.addMessage(to: target, kind: message.kind, text: message.text, imageData: message.imageData, fromMe: true)
            copy.quotedText = message.quotedText
            copy.quotedSender = message.quotedSender
        }
        try? context.save()
        forwardMessages = []
        isSelecting = false
        selectedIDs.removeAll()
        showToast("已发送")
    }

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
    }
}

struct ViewerImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
