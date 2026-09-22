import Foundation
import SwiftData

/// 首次启动时放一些示例数据，方便直接看效果；可随意编辑或删除。
enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Contact>())) ?? 0
        guard count == 0 else { return }

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

        try? context.save()
    }
}
