import XCTest

/// App Store 提出用スクリーンショットの撮影。
///
/// **これは検査ではなく撮影である。** 通常の `xcodebuild test` には含めない
/// （project.yml が別スキーム `PocketRT-Screenshots` を切ってある）。
/// 撮影は `tools/screenshots.sh` から呼ぶ。
///
/// **ファイル名の番号はタブの並び順**（計算 → 合算 → 換算 → 予定 → 品質 →
/// 免責）で、撮影順ではない。撮影順は画面遷移の都合で決まるが、提出時に
/// 並べ替える手間を残すと、次のリリースで並びが変わる。ストアの並びが
/// アプリの並びと一致していれば、入れた人が画面を探さずに済む。
///
/// 手で撮ると、機種・OS・入力値・言語が撮影のたびに変わり、再現できない。
/// 次のリリースで 1 枚だけ撮り直したいときに、他の絵と揃わなくなる。
/// 画面遷移と入力値をコードに固定してあるので、同じコマンドで何度でも
/// 同じ絵が出る。
///
/// 自施設の基準（D2）は `tools/screenshots.sh` がアプリのコンテナに保存
/// ファイルを直接置いている。**アプリ側にテスト用の注入口は作らない。**
/// 判定基準を起動引数から差し込める口を製品バイナリに残すと、臨床判断の
/// 根拠を外から書き換えられることになる。
// XCUIElement の操作は MainActor に隔離されている（Swift 6）。
// クラスごと隔離すれば、各メソッドに付けて回る必要がない。
@MainActor
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - 撮影本体

    /// 起動を `setUpWithError()` に置かない。クラスを `@MainActor` にしても
    /// override した `setUpWithError()` は基底クラスの nonisolated を引き継ぎ、
    /// XCUIApplication の操作が隔離違反になる。
    func testCaptureAppStoreScreenshots() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        // 1. 免責同意。初回起動でだけ出る。撮ってから閉じる。
        let accept = app.buttons["同意して開始"]
        if accept.waitForExistence(timeout: 5) {
            capture("09-disclaimer")
            accept.tap()
        }

        // 2. 計算タブ
        //
        // 入力しない。既定値が 60 Gy / 30 Fr / α/β 10 で、そのまま通常分割の
        // 代表例になっている。既定値を打ち直そうとすると、既定値を消す必要が
        // あり、`.decimalPad` では消去キーが typeText で効かない（実測）。
        // 撮りたい絵が既に出ているのに、消して打ち直す手順を足す理由がない。
        tab("計算")
        capture("01-simple-calc")

        // 3. 品質タブ — 肺 SBRT（内蔵プロトコル）
        tab("品質")
        fillQualityInputs()
        selectProtocol(containing: "0813")
        showVerdict()
        capture("06-quality-lung-sbrt")

        // 4. 品質タブ — 頭部定位照射（D4）
        selectProtocol(containing: "頭部")
        showVerdict()
        capture("07-quality-cranial-srs")

        // 5. 品質タブ — 自施設の基準（D2）
        selectProtocol(containing: "当院 肺SBRT")
        showVerdict()
        capture("08-quality-institutional")

        // 6. 自施設の基準の管理画面（D2 の編集画面）
        openProtocolMenu()
        tapMenuItem(containing: "自施設の基準を管理")
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        capture("10-institutional-editor")
        closeSheet()

        // 7. 予定タブ（条件と予測）
        tab("予定")
        capture("04-schedule")

        // 8. 予定タブ（カレンダー）。この機能の目玉は終了予定日の数字ではなく、
        //    祝日・週末・休止日を織り込んだカレンダーそのものなので、別に 1 枚撮る。
        scrollTo("カレンダー")
        capture("05-schedule-calendar")

        // 9. 合算タブ
        tab("合算")
        capture("02-multi-course")

        // 10. 換算タブ
        tab("換算")
        capture("03-conversion")
    }

    // MARK: - 画面の移動

    private func tab(_ name: String) {
        // キーボードが出ているとタブバーが隠れて押せない。先に閉じる。
        dismissKeyboard()
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "タブ「\(name)」が見つからない")
        button.tap()
    }

    /// タップして安全な最下限。これより下は、キーボードが出た瞬間に
    /// 覆われうる領域として扱う。
    private var safeTapLimit: CGFloat { app.frame.height * 0.45 }

    /// 対象を画面の上部（高さの 40% より上）まで送る。
    ///
    /// `swipeUp()` は 1 回で画面ほぼ 1 枚分動くため狙った位置に止められない。
    /// 座標を指定したドラッグで、1 回あたり画面の 30% だけ動かす。
    private func bringIntoUpperArea(_ element: XCUIElement, maxSteps: Int = 12) {
        let target = app.frame.height * 0.40
        var previous = CGFloat.greatestFiniteMagnitude
        for _ in 0..<maxSteps {
            let current = element.frame.midY
            if current <= target { return }
            // 動かなくなったら、それ以上スクロールできない（末尾に達した）。
            if abs(previous - current) < 1 { return }
            previous = current
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40)))
        }
    }

    // MARK: - 入力

    /// アクセシビリティラベルで数値欄を特定して入力する。
    /// `NumberField` が `.accessibilityLabel(Text(label))` を付けている。
    private func fill(_ label: String, _ value: String) {
        let field = app.textFields[label]
        guard field.waitForExistence(timeout: 5) else {
            // 見つからないときは、その瞬間の画面と、実際に見えている入力欄の
            // 一覧を残す。ラベル名の思い違いか、画面遷移が起きていないのかを、
            // 実行後に区別できるようにする。
            capture("FAILED-\(label)")
            XCTFail("入力欄「\(label)」が見つからない / 見えている欄=\(app.textFields.allElementsBoundByIndex.map(\.label))")
            return
        }

        // 画面下部の欄はキーボードに覆われ、tap がキーボードに吸われる。
        // 「押せるか」（isHittable）だけでは足りない。品質タブの Dmax は
        // y = 616pt に居座り、キーボード上端（約 621pt）の直上で isHittable が
        // true のままタップが届かなかった。位置で判断する。
        if !field.isHittable || field.frame.midY > safeTapLimit {
            dismissKeyboard()
            bringIntoUpperArea(field)
        }

        field.tap()
        guard app.keyboards.element.waitForExistence(timeout: 5) else {
            capture("FAILED-focus-\(label)")
            XCTFail("入力欄「\(label)」を叩いてもキーボードが出ない")
            return
        }

        // 既定値が入っている欄には打たない。
        //
        // 消してから打つ実装を試したが、`.decimalPad` では消去キーが
        // `typeText` で効かず 1 文字も消えなかった。既定値に打ち足された
        // 6060 / 3030 が、そのまま提出用の絵に写っていた。
        //
        // 黙って足し算するくらいなら止める。既定値のある欄は、既定値のまま
        // 撮るか、撮影対象から外すかを撮る側が決めるべきで、テストが
        // 勝手に混ぜてよい話ではない。
        if let current = field.value as? String, !current.isEmpty {
            capture("FAILED-prefilled-\(label)")
            XCTFail("入力欄「\(label)」に既定値「\(current)」が入っている。打ち足すと値が壊れる")
            return
        }

        field.typeText(value)

        // 打った値がそのまま入っているかを確かめる。ここを見ていなかったために、
        // 既定値に足し算された 6060 / 3030 が提出用の絵に写っていた。
        // 撮影は結果を人が見ないまま進むので、絵の中身は機械で確かめる。
        if let actual = field.value as? String, actual != value {
            capture("FAILED-value-\(label)")
            XCTFail("入力欄「\(label)」に \(value) を入れたが \(actual) になっている")
        }
    }

    /// 品質タブの入力。RTOG 0813 に合わせた値を入れる。
    ///
    /// **分割数は 5 でなければならない。** RTOG 0813 が検討したのは 5 分割で、
    /// 4 分割を入れると「このプロトコルが検討したのは 5 分割です」と出て判定が
    /// 出ない。判定の出ない絵を提出しても、この機能が何をするのか伝わらない。
    ///
    /// R100% = PIV / PTV    = 24 / 20 = 1.20
    /// R50%  = V50 / PTV    = 90 / 20 = 4.50
    /// D2cm  = 22 / 50      = 44.0 %Rx
    private func fillQualityInputs() {
        fill("PTV 体積", "20")
        fill("処方線量", "50")
        fill("分割数", "5")
        fill("PIV", "24")
        fill("PTV∩PIV", "19")
        fill("V50%", "90")
        fill("Dmax", "65")
        fill("D2%", "62")
        fill("D50%", "57")
        fill("D98%", "48")
        fill("D2cm", "22")
        dismissKeyboard()
    }

    /// `.keyboardType(.decimalPad)` にはリターンキーが無い。アプリ側の
    /// 「完了」ボタンとスクロール却下（`dismissibleKeyboard()`）で閉じる。
    /// **どちらも効かなければ失敗させる。** テストが進まないのではなく、
    /// 利用者もキーボードを閉じられないことを意味するため、黙って回避しない。
    private func dismissKeyboard() {
        guard app.keyboards.count > 0 else { return }

        let done = app.toolbars.buttons["完了"]
        if done.waitForExistence(timeout: 2) { done.tap() }

        if app.keyboards.count > 0 {
            app.scrollViews.firstMatch.swipeDown()
        }

        // 消え終わるまで待つ。閉じるアニメーションの最中にタップすると、
        // まだ画面に残っているキーボードに吸われる。「キーボードが無い」ことと
        // 「キーボードが消えつつある」ことは違う。
        if !app.keyboards.element.waitForNonExistence(timeout: 5) {
            capture("FAILED-keyboard-stuck")
            XCTFail("キーボードを閉じられない。「完了」もスクロールも効かない")
        }
    }

    // MARK: - プロトコルの選択

    private func openProtocolMenu() {
        let picker = app.buttons["プロトコル"]
        guard picker.waitForExistence(timeout: 5) else {
            capture("FAILED-protocol-menu")
            XCTFail("プロトコルの選択が見つからない")
            return
        }
        dismissKeyboard()
        bringIntoUpperArea(picker)
        picker.tap()
    }

    /// プロトコルを名前の一部で選ぶ。表示名は内蔵プリセットのラベル生成に
    /// 依存するので、完全一致では壊れやすい。
    private func selectProtocol(containing text: String) {
        openProtocolMenu()
        tapMenuItem(containing: text)
        XCTAssertTrue(app.buttons["プロトコル"].waitForExistence(timeout: 5))
    }

    private func tapMenuItem(containing text: String) {
        let item = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        guard item.waitForExistence(timeout: 5) else {
            capture("FAILED-menu-\(text)")
            XCTFail("メニュー項目「\(text)」が見つからない")
            return
        }
        item.tap()
    }

    private func closeSheet() {
        let close = app.buttons["閉じる"]
        if close.waitForExistence(timeout: 3) { close.tap() }
    }

    /// 見出しを画面の上部へ送る。撮りたい部分が画面の下に切れているとき使う。
    private func scrollTo(_ text: String) {
        let element = app.staticTexts[text]
        guard element.waitForExistence(timeout: 5) else {
            capture("FAILED-scrollTo-\(text)")
            XCTFail("「\(text)」が見つからない")
            return
        }
        bringIntoUpperArea(element)
    }

    /// 判定パネルを画面に入れる。
    ///
    /// プロトコルを選んだ直後の位置では、判定は画面の下に切れている。
    /// 品質タブで最も伝えたいのは指標の数値ではなく「基準内か、超えているか」
    /// の判定なので、そこが写らない絵を提出しても機能が伝わらない。
    private func showVerdict() {
        let verdict = app.staticTexts["判定"]
        guard verdict.waitForExistence(timeout: 5) else {
            capture("FAILED-verdict")
            XCTFail("判定パネルが見つからない")
            return
        }
        bringIntoUpperArea(verdict)
    }

    // MARK: - 撮影

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        // 既定は .deletedWhenTestSucceeds。成功したときこそ欲しい。
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
