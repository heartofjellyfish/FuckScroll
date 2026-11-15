import XCTest

final class ScrollStopperUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    private func launch(_ arguments: String...) {
        app.launchArguments = ["--en"] + arguments
        app.launch()
    }
    private func tap(_ id: String) {
        let element = app.buttons[id]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing action: \(id)")
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Cannot reach action: \(id)")
        element.tap()
    }
    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    // Opt-in physical check. Capture only an already-active Screen Time shield.
    func testRednoteShieldAppearanceOnDevice() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DUCK_CAPTURE_REDNOTE_SHIELD"] == "1")
        let rednote = XCUIApplication(bundleIdentifier: "com.xingin.discover")
        rednote.activate()
        let shieldTitle = NSPredicate(format: "label IN %@", ["再刷一条？", "One more?"])
        let title = rednote.staticTexts.matching(shieldTitle).firstMatch
        let systemTitle = XCUIApplication(bundleIdentifier: "com.apple.springboard").staticTexts.matching(shieldTitle).firstMatch
        try XCTSkipUnless(title.waitForExistence(timeout: 4) || systemTitle.exists, "No identifiable active shield")
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = "physical-rednote-shield"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
    func testSettingsCanPreviewRealShieldOnDevice() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DUCK_CAPTURE_REDNOTE_SHIELD"] == "1")
        app.launch()
        tap("home.settings")
        tap("settings.reminder")
        record("physical-edit-break-screen")
        tap("settings.preview")
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "trial.app."))
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 5))
        let rednoteChoice = choices.matching(NSPredicate(format: "label CONTAINS[cd] %@ OR label CONTAINS %@", "rednote", "小红书")).firstMatch
        // Screen Time can redact token labels from accessibility. The operator
        // can supply the row identifier after visually verifying its icon.
        let verifiedID = ProcessInfo.processInfo.environment["DUCK_REDNOTE_PREVIEW_RULE"] ?? ""
        let verified = app.buttons["trial.app." + verifiedID]
        try XCTSkipUnless(rednoteChoice.exists || (!verifiedID.isEmpty && verified.exists), "No verified rednote row")
        (rednoteChoice.exists ? rednoteChoice : verified).tap()
        let opened = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Open this app now", "现在打开这个 App"])).firstMatch
        XCTAssertTrue(opened.waitForExistence(timeout: 8))
        record("physical-preview-armed")
        do {
            let rednote = XCUIApplication(bundleIdentifier: "com.xingin.discover")
            rednote.activate()
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let title = NSPredicate(format: "label IN %@", ["再刷一条？", "One more?"])
            XCTAssertTrue(system.staticTexts.matching(title).firstMatch.waitForExistence(timeout: 5) ||
                          rednote.staticTexts.matching(title).firstMatch.exists)
            let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            proof.name = "physical-preview-shield"
            proof.lifetime = .keepAlways
            add(proof)
        }
        app.activate()
        if opened.exists { app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "关闭"])).firstMatch.tap() }
    }
    func testBreakTicketCounts() {
        var baseline: CGRect?
        for count in 1...9 {
            launch("--rehearsal-rest", "-rehearsalCount", String(count))
            let entry = app.buttons["home.rules"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            let first = app.descendants(matching: .any)["break.cell.0"].firstMatch
            XCTAssertTrue(first.exists)
            for index in 0..<count {
                let cell = app.descendants(matching: .any)["break.cell." + String(index)].firstMatch
                XCTAssertTrue(cell.exists)
                let secondRow = count > 5 && index >= (count + 1) / 2
                XCTAssertEqual(cell.frame.midY, first.frame.midY + (count == 9 ? CGFloat(index / 3) * 32 : (secondRow ? 36 : 0)), accuracy: 1)
                if index == count - 1 && secondRow && count < 9 {
                    let left = app.descendants(matching: .any)["break.cell." + String((count + 1) / 2)].firstMatch
                    XCTAssertEqual((left.frame.minX + cell.frame.maxX) / 2, app.frame.midX, accuracy: 1)
                }
            }
            let title = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "GO DO LITERALLY ANYTHING.")).firstMatch
            XCTAssertTrue(title.exists)
            let bounds = CGRect(x: entry.frame.midX, y: title.frame.maxY, width: entry.frame.width, height: entry.frame.minY - title.frame.maxY)
            if let baseline { XCTAssertEqual(baseline, bounds) } else { baseline = bounds }
            XCTAssertEqual(entry.frame.midX, app.frame.midX, accuracy: 1)
            record("break-count-" + String(count))
        }
    }
    func testUsageProbeRequiresAnExplicitSingleAppSelection() {
        launch("--usage-probe")
        XCTAssertTrue(app.staticTexts["Use the selected app directly on your iPhone for 2 minutes, then return here."].waitForExistence(timeout: 5))
        tap("3. Start recording")
        XCTAssertTrue(app.staticTexts["Choose exactly one app, no categories or websites."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Selected: 0 app(s)"].exists)
    }
    func testFirstRunDoesNotPretendToHavePermission() {
        launch("--welcome")
        XCTAssertTrue(app.buttons["welcome.setup"].waitForExistence(timeout: 5))
        record("first-welcome")
        tap("welcome.setup")
        XCTAssertTrue(app.buttons["setup.selectApp"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["setup.save"].exists)
        XCTAssertEqual(app.buttons["setup.selectApp"].label, "Select apps")
        XCTAssertFalse(app.buttons["Change apps"].exists)
        record("first-permission")
        tap("setup.selectApp")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "real iPhone")).firstMatch.exists)
        app.alerts.buttons["Got it"].tap()
        XCTAssertEqual(app.buttons["setup.selectApp"].label, "Select apps")
        record("01-permission-is-honest")
    }
    func testFirstSelectionAndDutyConfirmationScreens() {
        launch("--qa-limits", "--qa-first-selection")
        XCTAssertTrue(app.buttons["setup.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup.save"].label.contains("Put the duck on duty"))
        XCTAssertEqual(app.buttons["setup.usage.0"].value as? String, "20 min")
        XCTAssertEqual(app.buttons["setup.rest.0"].value as? String, "15 min")
        XCTAssertEqual(app.buttons["setup.selectApp"].label, "Change apps")
        record("first-selected")
        launch("--rehearsal-paused", "--qa-first-duty")
        tap("home.wake")
        XCTAssertTrue(app.staticTexts["ON DUTY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Close the duck. Limits still work."].exists)
        XCTAssertTrue(app.staticTexts["ALGORITHM VS. DUCK."].exists)
        XCTAssertTrue(app.staticTexts["I like our odds."].exists)
        record("first-ready")
    }
    func testPutPhoneDownTakesOneAction() {
        launch("--welcome", "--preview")
        XCTAssertTrue(app.buttons["interruption.putDown"].isHittable, "The primary exit must be visible without scrolling at the default text size")
        tap("interruption.putDown")
        XCTAssertTrue(app.buttons["welcome.setup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["alternatives.done"].exists)
        record("02-one-action-exit")
    }
    func testOptionalAlternativeRemembersWaterChoice() {
        launch("--welcome", "--preview")
        tap("interruption.alternatives")
        tap("alternatives.option.1")
        tap("alternatives.done")
        XCTAssertTrue(app.staticTexts["Hydrate. Overthink later."].waitForExistence(timeout: 5))
        record("03-water-not-a-generic-reward")
        tap("goodbye.close")
        XCTAssertTrue(app.buttons["welcome.setup"].waitForExistence(timeout: 5))
    }
    func testPreviewEscalatesThenCalmsDown() {
        launch("--welcome", "--preview")
        tap("interruption.escalate")
        tap("interruption.escalate")
        XCTAssertTrue(app.buttons["interruption.escalate"].label.contains("Chill."))
        record("04-rage")
        tap("interruption.escalate")
        XCTAssertTrue(app.buttons["interruption.escalate"].label.contains("Still scrolling?"))
    }
    func testUnavailableDutyDoesNotImpersonateOffOrResumePausedRules() {
        launch("--rehearsal-paused", "--qa-unreadable")
        XCTAssertTrue(app.staticTexts["CHECK DUTY"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["OFF DUTY"].exists)
        tap("home.settings")
        tap("settings.retryDuty")
        XCTAssertTrue(app.switches["settings.pause"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["OFF DUTY"].waitForExistence(timeout: 5))
        tap("home.wake")
        XCTAssertTrue(app.staticTexts["ON DUTY"].waitForExistence(timeout: 5))
    }
    func testOffDutyHomeCanWakeWithoutOpeningLimits() {
        launch("--rehearsal-paused")
        XCTAssertTrue(app.staticTexts["OFF DUTY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["RESTING MY EYES."].exists)
        XCTAssertFalse(app.buttons["home.rules"].exists)
        XCTAssertTrue(app.buttons["home.connect"].isHittable)
        record("home-paused")
        tap("home.wake")
        XCTAssertTrue(app.staticTexts["ON DUTY"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["setup.save"].exists)
        XCTAssertFalse(app.buttons["home.wake"].exists)
        tap("home.settings")
        app.switches["settings.pause"].tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["home.wake"].waitForExistence(timeout: 5))
    }
    func testBreakHomeShowsLimitsAndDutySettings() {
        launch("--rehearsal-rest")
        XCTAssertTrue(app.descendants(matching: .any)["break.cell.0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.rules"].exists)
        XCTAssertFalse(app.buttons["home.preview"].exists)
        XCTAssertFalse(app.buttons["home.connect"].exists)
        XCTAssertFalse(app.buttons["interruption.putDown"].exists)
        record("05-simplified-break")
        tap("home.settings")
        XCTAssertTrue(app.switches["settings.pause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings.pause"].isEnabled)
        XCTAssertFalse(app.buttons["settings.rules"].exists)
    }
    func testBreakExpiresWithoutReopeningTheApp() {
        launch("--rehearsal-rest", "--short-rest")
        let status = app.descendants(matching: .any)["break.cell.0"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 15), .completed)
        tap("home.settings")
        XCTAssertTrue(app.switches["settings.pause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings.pause"].isEnabled)
        record("06-expiry-without-extra-page")
    }
    func testSettingsToRulesOpensTheCorrectSheet() {
        launch("--home")
        XCTAssertEqual(app.buttons["home.connect"].label, "Select apps")
        XCTAssertFalse(app.buttons["home.rules"].exists)
        record("home-no-apps")
        tap("home.connect")
        XCTAssertTrue(app.buttons["setup.selectApp"].waitForExistence(timeout: 5))
        record("07-simple-setup")
    }
    func testSetupUsesCumulativeTimeWithoutShortcuts() {
        launch("--home", "--setup")
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["Time away counts toward a fresh start. Stay off an app for its break length."].exists)
        XCTAssertFalse(app.buttons["setup.save"].exists)
        XCTAssertTrue(app.buttons["setup.selectApp"].exists)
        XCTAssertFalse(app.staticTexts["Connect session detection"].exists)
        record("08-cumulative-setup")
    }
    func testCustomNegotiationTime() {
        launch("--qa-limits", "--en")
        let use = app.buttons["setup.usage.0"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        use.tap()
        app.buttons["Custom"].tap()
        let input = app.textFields["customTime.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("7")
        record("custom-time-seven")
        app.buttons["customTime.deal"].tap()
        XCTAssertEqual(use.value as? String, "7 min")
        let rest = app.buttons["setup.rest.0"]
        rest.tap(); app.buttons["Custom"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("0")
        XCTAssertFalse(app.buttons["customTime.deal"].isEnabled)
        input.typeText(XCUIKeyboardKey.delete.rawValue + "120")
        XCTAssertTrue(app.buttons["customTime.deal"].isEnabled)
        record("custom-break-120")
        app.buttons["customTime.cancel"].tap()
        XCTAssertEqual(rest.value as? String, "15 min")
    }
    func testGlanceKeepsLimitsLayout() {
        launch("--qa-limits")
        let use = app.buttons["setup.usage.0"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        let initial = use.frame
        record("duck-before")
        use.tap()
        app.buttons["30 min"].tap()
        record("duck-during")
        XCTAssertEqual(initial, use.frame)
        XCTAssertEqual(use.value as? String, "30 min")
        Thread.sleep(forTimeInterval: 3)
        record("duck-after")
        let replay = app.buttons["setup.replayDuck"]
        for _ in 0..<2 {
            replay.tap()
            XCTAssertEqual(use.value as? String, "30 min")
            XCTAssertEqual(initial, use.frame)
        }
        record("duck-replayed")
    }
    func testLenientGlancePersistsUntilTightened() {
        launch("--qa-limits")
        let use = app.buttons["setup.usage.0"]
        let duck = app.buttons["setup.replayDuck"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        let writing = duck.screenshot().pngRepresentation
        use.tap()
        app.buttons["30 min"].tap()
        Thread.sleep(forTimeInterval: 3)
        let watching = duck.screenshot().pngRepresentation
        XCTAssertNotEqual(writing, watching)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(watching, duck.screenshot().pngRepresentation)
        use.tap()
        app.buttons["5 min"].tap()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(writing, duck.screenshot().pngRepresentation)
    }
    func testDuckReactsWhenAnotherAppAlreadyHasALenientLimit() {
        launch("--qa-limits", "--qa-nine")
        let duck = app.buttons["setup.replayDuck"]
        let use = app.buttons["setup.usage.0"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        var previous = duck.screenshot().pngRepresentation
        for (field, minutes) in [(use, "10 min"), (app.buttons["setup.rest.0"], "20 min")] {
            field.tap()
            app.buttons[minutes].tap()
            XCTAssertEqual(field.value as? String, minutes)
            let current = duck.screenshot().pngRepresentation
            XCTAssertNotEqual(current, previous, "An existing 30-minute rule masked another app's edit")
            previous = current
        }
        record("nine-updated-duck")
    }
    func testRuleSummaryUsesSelectedTimes() {
        launch("--qa-limits")
        let use = app.buttons["setup.usage.0"]
        let rest = app.buttons["setup.rest.0"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        XCTAssertEqual(use.value as? String, "5 min")
        use.tap()
        app.buttons["20 min"].tap()
        XCTAssertEqual(use.value as? String, "20 min")
        XCTAssertEqual(rest.value as? String, "15 min")
        rest.tap()
        app.buttons["10 min"].tap()
        XCTAssertEqual(rest.value as? String, "10 min")
        XCTAssertEqual(use.value as? String, "20 min")
    }
    func testThreeAppsPinFooterAndHoldPose() {
        launch("--qa-limits", "--qa-three")
        let last = app.buttons["setup.usage.2"]
        let change = app.buttons["setup.selectApp"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(change.frame.minY, last.frame.maxY)
        XCTAssertLessThan(app.frame.maxY - change.frame.maxY, 85)
        record("three-limits")
        let duck = app.buttons["setup.replayDuck"]
        let before = duck.screenshot().pngRepresentation
        app.buttons["setup.usage.0"].tap()
        app.buttons["10 min"].tap()
        let after = duck.screenshot().pngRepresentation
        XCTAssertNotEqual(before, after)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(after, duck.screenshot().pngRepresentation)
    }
    func testNineAppsKeepFooterWhileScrolling() {
        launch("--qa-limits", "--qa-nine")
        let save = app.buttons["setup.save"]
        let change = app.buttons["setup.selectApp"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        let footerY = change.frame.midY
        record("nine-top")
        let last = app.buttons["setup.usage.8"]
        app.scrollViews.firstMatch.swipeUp()
        if !last.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(app.staticTexts["Calendar"].isHittable)
        XCTAssertTrue(app.staticTexts["Use for"].isHittable)
        XCTAssertEqual(footerY, change.frame.midY, accuracy: 1)
        last.tap()
        app.buttons["45 min"].tap()
        XCTAssertEqual(last.value as? String, "45 min")
        XCTAssertEqual(app.buttons["setup.rest.8"].value as? String, "5 min")
        record("nine-bottom")
        save.tap()
        // With sample identities, the normal save path must report missing device authorization.
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4))
    }
    func testUsageLimitIsEditableDuringBreak() {
        launch("--qa-limits", "--qa-locked")
        XCTAssertTrue(app.staticTexts["Next round"].waitForExistence(timeout: 5))
        let use = app.buttons["setup.usage.0"]
        use.tap()
        app.buttons["30 min"].tap()
        XCTAssertEqual(use.value as? String, "30 min")
        XCTAssertTrue(app.buttons["setup.save"].isEnabled)
    }
    func testChineseOptionalFlow() {
        app.launchArguments = ["--zh", "--welcome", "--preview"]
        app.launch()
        tap("interruption.alternatives")
        tap("alternatives.option.1")
        tap("alternatives.done")
        XCTAssertTrue(app.staticTexts["先喝水。再内耗。"].waitForExistence(timeout: 5))
        record("10-chinese-water-flow")
        tap("goodbye.close")
        XCTAssertTrue(app.buttons["welcome.setup"].waitForExistence(timeout: 5))
    }
    func testReminderAnnotationLengths() {
        let samples = [
            ("en", "Pause.", "Go", "short"),
            ("en", "Your thumb could use a coffee break too.", "Drop the phone!!", "long"),
            ("zh-Hans", "刷完这一条就放下手机吧，今晚还有更值得你花时间去做的事。", "把手机轻轻放下现在给自己一点时间", "wrapped")
        ]
        for (locale, message, action, name) in samples {
            launch("--settings", "--locale-" + locale, "-customReminder", message, "-customReminderAction", action)
            tap("settings.reminder")
            let button = app.buttons["settings.editAction"]
            XCTAssertTrue(button.waitForExistence(timeout: 4))
            XCTAssertTrue(button.label.contains(action))
            record("annotations-" + name)
        }
    }
    func testNativeDutySwitchReportsBothPositions() {
        launch("--settings", "--rehearsal-paused")
        let control = app.switches["settings.pause"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        XCTAssertEqual(control.value as? String, "0")
        record("switch-off")
        control.tap()
        XCTAssertEqual(control.value as? String, "1")
        record("switch-on")
        control.tap()
        XCTAssertEqual(control.value as? String, "0")
    }
    func testGroundRulesLanguageDisclosure() {
        launch("--settings", "--rehearsal-rest")
        let language = app.buttons["settings.language"]
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(language.frame.midY, app.buttons["settings.reminder"].frame.midY)
        XCTAssertEqual(language.value as? String, "Collapsed")
        record("ground-rules-on")
        language.tap()
        XCTAssertEqual(language.value as? String, "Expanded")
        app.buttons["简体中文"].tap()
        XCTAssertEqual(language.value as? String, "已收起")
        XCTAssertTrue(app.buttons["settings.help"].label.contains("使用说明"))
        launch("--settings")
        XCTAssertTrue(app.switches["settings.pause"].waitForExistence(timeout: 5))
        record("ground-rules-off")
    }
    func testGroundRulesAndReminderAction() {
        launch("--settings")
        record("ground-rules-header")
        app.buttons["settings.help"].tap()
        XCTAssertTrue(app.staticTexts["Each app adds up visits and locks at its limit."].exists)
        XCTAssertTrue(app.staticTexts["Close the duck. Limits still work."].exists)
        record("ground-rules-expanded")
        app.buttons["settings.help"].tap()
        tap("settings.reminder")
        record("miniature")
        tap("settings.editMessage")
        let field = app.textFields["settings.reminderText"]
        let example = "Your thumb could use a coffee break too."
        field.typeKey("a", modifierFlags: .command)
        field.typeText(example + "XX\n")
        tap("settings.editAction")
        let action = app.textFields["settings.actionText"]
        action.typeKey("a", modifierFlags: .command)
        action.typeText("Drop the phone!!EXTRA")
        XCTAssertEqual(action.value as? String, "Drop the phone!!")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let aboveKeyboard = NSPredicate { _, _ in action.frame.maxY <= keyboard.frame.minY }
        expectation(for: aboveKeyboard, evaluatedWith: action)
        waitForExpectations(timeout: 3)
        record("custom-action-typing")
        action.typeText("\n")
        record("custom-reminder-editor")
        tap("settings.preview")
        XCTAssertTrue(app.staticTexts[example].exists)
        record("reminder-action")
        XCTAssertTrue(app.buttons["preview.proceed"].label.contains("Drop the phone!!"))
        app.buttons["preview.proceed"].tap()
        XCTAssertTrue(app.staticTexts["Go say hi."].waitForExistence(timeout: 4))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        tap("settings.editAction")
        action.typeKey("a", modifierFlags: .command)
        action.typeText(XCUIKeyboardKey.delete.rawValue + "\n")
        tap("settings.editMessage")
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.typeKey("a", modifierFlags: .command)
        field.typeText(XCUIKeyboardKey.delete.rawValue + "\n")
    }
    func testLargeTextStillHasAReachableExit() {
        app.launchArguments = ["--en", "--welcome", "--preview", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        record("11-large-text-before-scroll")
        tap("interruption.putDown")
        XCTAssertTrue(app.buttons["welcome.setup"].waitForExistence(timeout: 5))
    }
}
