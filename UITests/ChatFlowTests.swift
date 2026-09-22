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
        capture("01-chats")
        let search = app.textFields["search.field"]
        search.tap()
        search.typeText("NoMatchingContact")
        XCTAssertTrue(app.staticTexts["无搜索结果"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["林小雨"].exists)
        app.buttons["tab.1"].tap()
        XCTAssertTrue(app.staticTexts["新的朋友"].waitForExistence(timeout: 3))
        capture("02-contacts")
        app.buttons["tab.2"].tap()
        XCTAssertTrue(app.staticTexts["朋友圈"].waitForExistence(timeout: 3))
        capture("03-discover")
        app.buttons["tab.3"].tap()
        XCTAssertTrue(app.buttons["me.settings"].waitForExistence(timeout: 3))
        capture("04-me")
        app.buttons["me.settings"].tap()
        XCTAssertTrue(app.switches["settings.editMode"].waitForExistence(timeout: 3))
        capture("05-settings")
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
}
