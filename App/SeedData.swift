import Foundation
import SwiftData

/// 首次启动时放一些示例数据，方便直接看效果；可随意编辑或删除。
enum SeedData {
    static let fileHelperName = "文件传输助手"

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Contact>())) ?? 0
        guard count == 0 else {
            ensureFileHelper(context)
            return
        }

        _ = context.me()
        let now = Date()
        func minutesAgo(_ m: Double) -> Date { now.addingTimeInterval(-m * 60) }

        let xiaoyu = Contact(name: "林小雨")
        let mom = Contact(name: "妈妈")
        let ajie = Contact(name: "阿杰")
        let chen = Contact(name: "陈经理")
        [xiaoyu, mom, ajie, chen].forEach { context.insert($0) }

        let c1 = context.conversation(with: xiaoyu)
        context.addMessage(to: c1, text: "下班了吗？", fromMe: false, at: minutesAgo(48))
        context.addMessage(to: c1, text: "快了，还有个会", fromMe: true, at: minutesAgo(46))
        context.addMessage(to: c1, text: "那晚上一起吃饭吧，新开了家火锅", fromMe: false, at: minutesAgo(12))
        let place = context.addMessage(to: c1, kind: .location, text: "西湖文化广场", fromMe: false, at: minutesAgo(11.5))
        place.locationAddress = "浙江省杭州市拱墅区"
        place.latitude = 30.2771
        place.longitude = 120.1655
        context.addMessage(to: c1, text: "七点半楼下见？", fromMe: false, at: minutesAgo(11))
        c1.unread = 2

        let c2 = context.conversation(with: mom)
        context.addMessage(to: c2, text: "周末回家吃饭吗", fromMe: false, at: minutesAgo(60 * 26))
        context.addMessage(to: c2, text: "回的，周六中午到", fromMe: true, at: minutesAgo(60 * 25))
        context.addMessage(to: c2, text: "好，给你炖汤", fromMe: false, at: minutesAgo(60 * 25 - 3))

        let c3 = context.conversation(with: ajie)
        context.addMessage(to: c3, text: "资料我发你邮箱了", fromMe: false, at: minutesAgo(60 * 50))
        context.addMessage(to: c3, text: "收到，谢啦", fromMe: true, at: minutesAgo(60 * 49))
        c3.muted = true

        let c4 = context.conversation(with: chen)
        context.addMessage(to: c4, text: "明天上午十点的会改到下午两点", fromMe: false, at: minutesAgo(60 * 24 * 4))
        context.addMessage(to: c4, text: "好的，收到", fromMe: true, at: minutesAgo(60 * 24 * 4 - 5))

        let helper = Contact(name: fileHelperName)
        helper.isSystem = true
        context.insert(helper)
        let c5 = context.conversation(with: helper)
        context.addMessage(to: c5, text: "照片已同步到电脑", fromMe: true, at: minutesAgo(60 * 3))

        try? context.save()
        UserDefaults.standard.set(true, forKey: fileHelperKey)
    }

    private static let fileHelperKey = "seededFileHelper"

    /// 旧版本升级：只补充联系人（可在"发起聊天"中选择），不往已有数据里插入消息
    private static func ensureFileHelper(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: fileHelperKey) else { return }
        let helper = Contact(name: fileHelperName)
        helper.isSystem = true
        context.insert(helper)
        try? context.save()
        UserDefaults.standard.set(true, forKey: fileHelperKey)
    }
}
