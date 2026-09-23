import Foundation
import SwiftData

/// 首次启动时放一些示例数据，方便直接看效果；可随意编辑或删除。
enum SeedData {
    static let fileHelperName = "文件传输助手"

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Contact>())) ?? 0
        guard count == 0 else {
            ensureFileHelper(context)
            ensureAccounts(context)
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

        // 群聊
        let group = context.createGroup(with: [xiaoyu, ajie, chen], name: "周末爬山", at: minutesAgo(100))
        let g1 = context.addMessage(to: group, text: "周六早上八点地铁站集合？", fromMe: false, at: minutesAgo(95))
        g1.senderID = ajie.id
        g1.senderName = ajie.name
        let g2 = context.addMessage(to: group, text: "可以，我带点水果", fromMe: false, at: minutesAgo(90))
        g2.senderID = xiaoyu.id
        g2.senderName = xiaoyu.name
        context.addMessage(to: group, text: "好的，我查一下天气", fromMe: true, at: minutesAgo(88))
        let g3 = context.addMessage(to: group, text: "周六晴，适合出门", fromMe: false, at: minutesAgo(80))
        g3.senderID = chen.id
        g3.senderName = chen.name
        group.muted = true
        group.unread = 3

        // 朋友圈
        let me = context.me()
        let m1 = Moment(author: xiaoyu, text: "新开的火锅店，排了半小时队，值得。", createdAt: minutesAgo(40))
        m1.likes = [ajie.name]
        let m2 = Moment(author: ajie, text: "今天跑了十公里，给自己点个赞。", createdAt: minutesAgo(60 * 5))
        m2.likes = [xiaoyu.name, chen.name]
        m2.likedByMe = true
        let m3 = Moment(author: me, text: "周末愉快！", createdAt: minutesAgo(60 * 26))
        [m1, m2, m3].forEach { context.insert($0) }
        let c1m = MomentComment(authorName: ajie.name, fromMe: false, text: "下次带我一个")
        context.insert(c1m)
        c1m.moment = m1
        let c2m = MomentComment(authorName: chen.name, fromMe: false, text: "厉害，保持！")
        context.insert(c2m)
        c2m.moment = m2

        // 新的朋友
        context.insert(FriendRequest(name: "周同学", greeting: "你好，我是周末爬山群里的朋友"))

        try? context.save()
        UserDefaults.standard.set(true, forKey: fileHelperKey)
        ensureAccounts(context, force: true)
    }

    private static let accountsKey = "seededOfficialAccounts"

    /// 公众号、服务号和文章（虚构的本地示例内容）；升级用户也会补充
    /// force：全新数据库时总是写入（标记存在 UserDefaults，可能比数据库活得久）
    private static func ensureAccounts(_ context: ModelContext, force: Bool = false) {
        guard force || !UserDefaults.standard.bool(forKey: accountsKey) else { return }
        let now = Date()
        func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

        let life = OfficialAccount(name: "生活小百科", intro: "每天一点生活小技巧。", isService: false, colorHex: 0x07C160, symbol: "leaf.fill")
        let city = OfficialAccount(name: "城市周末", intro: "周末去哪儿、吃什么、玩什么。", isService: false, colorHex: 0xFA9D3B, symbol: "map.fill")
        let work = OfficialAccount(name: "效率手册", intro: "工作与学习的方法整理。", isService: false, colorHex: 0x1485EE, symbol: "checklist")
        let weather = OfficialAccount(name: "本地天气服务", intro: "天气提醒示例服务号。", isService: true, colorHex: 0x10AEFF, symbol: "cloud.sun.fill")
        [life, city, work, weather].forEach { context.insert($0) }

        let articles: [(OfficialAccount, String, String, Double)] = [
            (life, "换季时节，衣物收纳的三个小方法",
             "换季整理衣柜时，先把一年没穿过的衣服挑出来，决定捐赠还是保留。\n\n厚重的外套可以用真空收纳袋压缩，节省大约一半空间；毛衣适合叠放，挂着容易变形。\n\n最后在衣柜里放一两包干燥剂，梅雨季节也不容易受潮。", 3),
            (life, "厨房里常被忽略的清洁死角",
             "抽油烟机的滤网、水槽下方和冰箱门封条，是最容易积攒油污和细菌的地方。\n\n滤网可以用热水加小苏打浸泡二十分钟再刷洗；门封条用软布蘸稀释的白醋擦拭即可。", 30),
            (city, "适合周末散步的城市公园路线",
             "如果只有半天时间，可以选一条沿河步道，从公园南门进，沿水边走到北门，全程大约四公里。\n\n沿途有几处长椅和小卖部，适合带家人慢慢走。傍晚光线最好，适合拍照。", 8),
            (city, "雨天也能去的五个室内好去处",
             "图书馆、美术馆、室内攀岩馆、手作工坊和老字号茶馆，都是下雨天不错的选择。\n\n出发前记得查看开放时间，部分场馆需要提前预约。", 50),
            (work, "用番茄工作法对抗拖延",
             "番茄工作法的核心很简单：专注工作 25 分钟，然后休息 5 分钟，每完成四个番茄休息更长时间。\n\n关键在于番茄钟期间不处理消息，把突然想到的事记在纸上，结束后再处理。", 5),
            (weather, "本周天气提醒：周末晴，早晚温差大",
             "预计周六、周日以晴为主，白天最高气温 24℃，夜间最低 13℃。\n\n早晚出门请适当添衣，紫外线较强，外出注意防晒。（示例内容）", 2),
        ]
        for (account, title, body, hours) in articles {
            let article = Article(title: title, body: body, publishedAt: hoursAgo(hours))
            context.insert(article)
            article.account = account
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: accountsKey)
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
