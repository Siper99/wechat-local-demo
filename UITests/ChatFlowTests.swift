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
        app.staticTexts["妈妈"].swipeLeft()
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
        capture("15-photo-sheet")
        app.buttons["取消"].tap()

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
}
