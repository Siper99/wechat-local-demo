import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        Task { @MainActor in
            let payload = await SharePayload.load(from: extensionContext)
            let root = ShareImportView(
                payload: payload,
                onDone: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
                onCancel: { [weak self] in self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled)) }
            )
            .modelContainer(SharedStore.makeContainer())

            let host = UIHostingController(rootView: root)
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }
}

struct SharePayload {
    var text = ""
    var images: [Data] = []

    static func load(from context: NSExtensionContext?) async -> SharePayload {
        var payload = SharePayload()
        var texts: [String] = []
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let data = await loadImage(provider) { payload.images.append(data) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL {
                    texts.append(url.absoluteString)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String {
                    texts.append(text)
                }
            }
        }
        payload.text = texts.joined(separator: "\n")
        return payload
    }

    private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) else { return nil }
        var raw: Data?
        if let url = item as? URL {
            raw = try? Data(contentsOf: url)
        } else if let data = item as? Data {
            raw = data
        } else if let image = item as? UIImage {
            raw = image.jpegData(compressionQuality: 0.9)
        }
        guard let raw else { return nil }
        return ImageUtil.downsampledJPEG(raw)
    }
}

struct ShareImportView: View {
    let payload: SharePayload
    var onDone: () -> Void
    var onCancel: () -> Void

    @Query private var conversations: [Conversation]
    @State private var text: String
    @State private var selectedID: UUID?
    @State private var newName = ""
    @State private var fromMe = false
    @State private var sentAt = Date()
    @State private var errorText: String?

    init(payload: SharePayload, onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.payload = payload
        self.onDone = onDone
        self.onCancel = onCancel
        _text = State(initialValue: payload.text)
    }

    private var sorted: [Conversation] {
        conversations.sorted { $0.lastActivity > $1.lastActivity }
    }

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }

    private var canInsert: Bool {
        let hasTarget = selectedID != nil || !trimmedName.isEmpty
        let hasContent = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !payload.images.isEmpty
        return hasTarget && hasContent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    if !payload.images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(payload.images.enumerated()), id: \.offset) { _, data in
                                    if let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                        }
                    }
                    TextField(payload.images.isEmpty ? "消息内容" : "附带文字（可不填）", text: $text, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section("发送方") {
                    Picker("发送方", selection: $fromMe) {
                        Text("对方").tag(false)
                        Text("我").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("插入到") {
                    ForEach(sorted) { conversation in
                        Button {
                            selectedID = conversation.id
                            newName = ""
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(contact: conversation.peer, size: 32)
                                Text(conversation.title).foregroundStyle(.primary)
                                Spacer()
                                if selectedID == conversation.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                }
                            }
                        }
                    }
                    TextField("或新建对话：输入对方名字", text: $newName)
                        .onChange(of: newName) { _, value in
                            if !value.isEmpty { selectedID = nil }
                        }
                }

                Section("时间") {
                    DatePicker("发送时间", selection: $sentAt)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("导入到微信（本地仿真）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("插入", action: insert).disabled(!canInsert)
                }
            }
            .onAppear {
                if selectedID == nil { selectedID = sorted.first?.id }
            }
        }
    }

    private func insert() {
        let item = PendingImport(
            conversationID: trimmedName.isEmpty ? selectedID : nil,
            newContactName: trimmedName.isEmpty ? nil : trimmedName,
            fromMe: fromMe,
            text: text,
            sentAt: sentAt
        )
        do {
            try Inbox.write(item, images: payload.images)
            onDone()
        } catch {
            errorText = "写入失败：请确认 App Group 已配置。\(error.localizedDescription)"
        }
    }
}
