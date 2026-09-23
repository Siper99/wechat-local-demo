import XCTest

final class ChatFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-editMode", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["林小雨"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMainPagesAndSearch() {
        XCTAssertTrue(app.buttons["chats.desktopLogin"].exists)
        XCTAssertTrue(app.staticTexts["文件传输助手"].exists)
        capture("01-chats")
        let search = app.textFields["search.field"]
        search.tap()
        search.typeText("NoMatchingContact")
        XCTAssertTrue(app.staticTexts["无搜索结果"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["林小雨"].exists)
        app.buttons["tab.1"].tap()
        XCTAssertTrue(app.staticTexts["新的朋友"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["企业微信联系人"].exists)
        XCTAssertFalse(app.staticTexts["文件传输助手"].exists)
        capture("02-contacts")
        app.buttons["tab.2"].tap()
        XCTAssertTrue(app.staticTexts["朋友圈"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["附近的人"].exists)
        capture("03-discover")
        app.buttons["tab.3"].tap()
        XCTAssertTrue(app.buttons["me.settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["小店与卡包"].exists)
        capture("04-me")
        app.buttons["me.settings"].tap()
        XCTAssertTrue(app.buttons["settings.simulation"].waitForExistence(timeout: 3))
        app.buttons["settings.simulation"].tap()
        XCTAssertTrue(app.switches["settings.editMode"].waitForExistence(timeout: 3))
        capture("05-settings")
    }

    func testDraftSurvivesReturningToList() {
        app.staticTexts["林小雨"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "chat.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Draft to resume")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["[草稿]"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Draft to resume"].exists)
        app.staticTexts["林小雨"].tap()
        XCTAssertEqual(input.value as? String, "Draft to resume")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts["Draft to resume"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertFalse(app.staticTexts["[草稿]"].exists)
    }

    func testComposeQuoteFavoriteAndPanels() {
        app.staticTexts["林小雨"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "chat.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.0"].exists)
        capture("06-chat")
        app.buttons["更多功能"].tap()
        XCTAssertTrue(app.buttons["拍摄"].waitForExistence(timeout: 3))
        capture("07-attachments")
        app.buttons["表情"].tap()
        capture("08-emoji")
        input.tap()
        input.typeText("Hello from UI test")
        app.buttons["chat.send"].tap()
        let message = app.staticTexts["Hello from UI test"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.press(forDuration: 1)
        XCTAssertTrue(app.buttons["引用"].waitForExistence(timeout: 3))
        capture("09-message-menu")
        app.buttons["引用"].tap()
        XCTAssertTrue(app.buttons["取消引用"].waitForExistence(timeout: 3))
        input.tap()
        input.typeText("Quoted reply")
        app.buttons["chat.send"].tap()
        let reply = app.staticTexts["Quoted reply"].firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 3))
        reply.tap()
        capture("10-quoted-message")
        reply.press(forDuration: 1)
        app.buttons["收藏"].tap()
        app.buttons["聊天信息"].tap()
        XCTAssertTrue(app.staticTexts["查找聊天记录"].waitForExistence(timeout: 3))
        capture("11-chat-info")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["tab.3"].waitForExistence(timeout: 3))
        app.buttons["tab.3"].tap()
        app.buttons["me.favorites"].tap()
        XCTAssertTrue(app.staticTexts["Quoted reply"].waitForExistence(timeout: 3))
        capture("12-favorites")
    }

    func testLocationMessageAndBackButton() {
        app.staticTexts["林小雨"].tap()
        XCTAssertTrue(app.buttons["nav.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["西湖文化广场"].waitForExistence(timeout: 3))
        app.buttons["更多功能"].tap()
        app.buttons["位置"].tap()
        let name = app.textFields["location.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Test Place")
        app.buttons["location.send"].tap()
        XCTAssertTrue(app.staticTexts["Test Place"].waitForExistence(timeout: 20))
        capture("13-location")
        app.buttons["nav.back"].tap()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 3))
    }

    func testSwipeActionsPhotoSheetVoiceAndProfile() {
        // 会话左滑：圆角“标为未读 / 删除”，删除需确认
        // 从行右侧横向拖到左侧，与手指左滑一致（swipeLeft 在短文本上距离太短）
        let name = app.staticTexts["妈妈"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        let rowY = name.frame.midY
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: window.frame.width - 40, dy: rowY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 60, dy: rowY)))
        XCTAssertTrue(app.buttons["标为未读"].waitForExistence(timeout: 3))
        capture("14-swipe-actions")
        app.buttons["删除"].tap()
        XCTAssertTrue(app.buttons["确认删除"].waitForExistence(timeout: 3))
        app.buttons["确认删除"].tap()
        XCTAssertFalse(app.staticTexts["妈妈"].waitForExistence(timeout: 2))

        // 白底半屏选图
        app.staticTexts["林小雨"].tap()
        XCTAssertTrue(app.buttons["更多功能"].waitForExistence(timeout: 5))
        app.buttons["更多功能"].tap()
        app.buttons["相册"].tap()
        XCTAssertTrue(app.buttons["photos.send"].waitForExistence(timeout: 5))
        // 首次打开会有系统“私密访问照片”说明
        let ok = app.buttons["好"]
        if ok.waitForExistence(timeout: 2) { ok.tap() }
        capture("15-photo-sheet")
        app.buttons["photos.cancel"].tap()

        // 语音输入样式
        app.buttons["切换语音"].tap()
        XCTAssertTrue(app.buttons["语音转文字"].waitForExistence(timeout: 3))
        capture("16-voice-input")
        app.buttons["nav.back"].tap()

        // 好友资料页
        app.buttons["tab.1"].tap()
        app.staticTexts["阿杰"].tap()
        XCTAssertTrue(app.buttons["contact.edit"].waitForExistence(timeout: 3))
        capture("17-contact-profile")
        app.buttons["contact.sendMessage"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "chat.input").firstMatch.waitForExistence(timeout: 5))
    }

    private func back() {
        app.navigationBars.buttons.firstMatch.tap()
    }

    func testMeEntriesOpen() {
        app.buttons["tab.3"].tap()
        // 服务
        app.buttons["me.services"].tap()
        XCTAssertTrue(app.buttons["services.wallet"].waitForExistence(timeout: 3))
        capture("20-services")
        back()
        // 收藏：新建笔记
        app.buttons["me.favorites"].tap()
        app.buttons["favorites.newNote"].tap()
        let editor = app.textViews["note.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.typeText("Note from UI test")
        back()
        XCTAssertTrue(app.staticTexts["Note from UI test"].waitForExistence(timeout: 3))
        capture("21-favorites")
        back()
        // 朋友圈：发表文字动态并点赞
        app.buttons["me.moments"].tap()
        XCTAssertTrue(app.buttons["moments.compose"].waitForExistence(timeout: 3))
        app.buttons["moments.compose"].tap()
        let text = app.textFields["moments.composeText"]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.tap()
        text.typeText("Moment from UI test")
        app.buttons["moments.post"].tap()
        XCTAssertTrue(app.staticTexts["Moment from UI test"].waitForExistence(timeout: 3))
        app.buttons["点赞或评论"].firstMatch.tap()
        app.buttons["moments.like"].tap()
        capture("22-my-moments")
        app.buttons["moments.back"].tap()
        // 作品、小店与卡包、表情
        app.buttons["me.works"].tap()
        XCTAssertTrue(app.staticTexts["还没有作品"].waitForExistence(timeout: 3))
        back()
        app.buttons["me.wallet"].tap()
        app.buttons["wallet.add"].tap()
        let title = app.textFields["wallet.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("Coffee Card")
        app.buttons["wallet.save"].tap()
        XCTAssertTrue(app.staticTexts["Coffee Card"].waitForExistence(timeout: 3))
        capture("23-wallet")
        back()
        app.buttons["me.stickers"].tap()
        XCTAssertTrue(app.navigationBars["我的表情"].waitForExistence(timeout: 3))
        back()
        app.buttons["me.qrcode"].tap()
        XCTAssertTrue(app.navigationBars["我的二维码"].waitForExistence(timeout: 3))
        capture("24-qrcode")
    }

    func testDiscoverEntriesOpen() {
        app.buttons["tab.2"].tap()
        app.buttons["discover.朋友圈"].tap()
        XCTAssertTrue(app.staticTexts["新开的火锅店，排了半小时队，值得。"].waitForExistence(timeout: 3))
        capture("25-moments")
        app.buttons["moments.back"].tap()
        app.buttons["discover.视频号"].tap()
        XCTAssertTrue(app.staticTexts["还没有视频"].waitForExistence(timeout: 3))
        app.buttons["返回"].firstMatch.tap()
        app.buttons["discover.直播"].tap()
        XCTAssertTrue(app.buttons["live.start"].waitForExistence(timeout: 3))
        back()
        app.buttons["discover.扫一扫"].tap()
        XCTAssertTrue(app.buttons["scan.album"].waitForExistence(timeout: 5))
        back()
        app.buttons["discover.听一听"].tap()
        XCTAssertTrue(app.staticTexts["还没有音乐"].waitForExistence(timeout: 3))
        back()
        app.buttons["discover.看一看"].tap()
        XCTAssertTrue(app.staticTexts["用番茄工作法对抗拖延"].waitForExistence(timeout: 3))
        app.staticTexts["用番茄工作法对抗拖延"].tap()
        XCTAssertTrue(app.buttons["article.watching"].waitForExistence(timeout: 3))
        capture("26-article")
        back()
        back()
        app.buttons["discover.搜一搜"].tap()
        let field = app.textFields["searchHub.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("abc")
        XCTAssertTrue(app.buttons["search.web"].waitForExistence(timeout: 3))
        capture("27-search")
        back()
        app.buttons["discover.附近的人"].tap()
        XCTAssertTrue(app.navigationBars["附近的人"].waitForExistence(timeout: 3))
        back()
        app.buttons["discover.游戏"].tap()
        app.buttons["games.2048"].tap()
        XCTAssertTrue(app.navigationBars["2048"].waitForExistence(timeout: 3))
        capture("28-game")
        back()
        back()
        app.buttons["discover.小程序"].tap()
        app.buttons["mini.calculator"].tap()
        app.buttons["calculator.7"].tap()
        app.buttons["calculator.×"].tap()
        app.buttons["calculator.6"].tap()
        app.buttons["calculator.="].tap()
        XCTAssertEqual(app.staticTexts["calculator.display"].label, "42")
    }

    func testContactEntriesAndGroupChat() {
        XCTAssertTrue(app.staticTexts["周末爬山"].waitForExistence(timeout: 3))
        app.buttons["tab.1"].tap()
        app.staticTexts["contacts.entry.群聊"].tap()
        XCTAssertTrue(app.staticTexts["周末爬山(4)"].waitForExistence(timeout: 3))
        app.staticTexts["周末爬山(4)"].tap()
        XCTAssertTrue(app.staticTexts["周六晴，适合出门"].waitForExistence(timeout: 5))
        capture("29-group-chat")
        app.buttons["nav.back"].tap()
        back()
        app.staticTexts["contacts.entry.新的朋友"].tap()
        XCTAssertTrue(app.buttons["newFriends.accept.周同学"].waitForExistence(timeout: 3))
        app.buttons["newFriends.accept.周同学"].tap()
        XCTAssertTrue(app.staticTexts["已添加"].waitForExistence(timeout: 3))
        back()
        app.staticTexts["contacts.entry.公众号"].tap()
        XCTAssertTrue(app.staticTexts["生活小百科"].waitForExistence(timeout: 3))
        back()
        app.staticTexts["contacts.entry.标签"].tap()
        XCTAssertTrue(app.navigationBars["标签"].waitForExistence(timeout: 3))
        back()
        app.staticTexts["阿杰"].tap()
        app.buttons["contact.moments"].tap()
        XCTAssertTrue(app.staticTexts["今天跑了十公里，给自己点个赞。"].waitForExistence(timeout: 3))
    }
}
