import Testing
import Foundation
@testable import PocketRT

@Suite("自施設の判定基準の型")
struct CustomProtocolTests {

    @Test("Codable の往復で内容が一致する")
    func codableRoundTrip() throws {
        let original = CustomProtocol(
            id: "p1", name: "当院基準", note: "肺 SBRT 用",
            thresholds: [
                .r50: MetricThreshold(within: 4.5, tolerated: 5.5),
                .d2cm: MetricThreshold(within: 60.0, tolerated: nil)
            ],
            createdAt: Date(timeIntervalSince1970: 0))

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomProtocol.self, from: data)
        #expect(decoded == original)
    }

    @Test("MetricKey は 3 指標を持つ")
    func metricKeyCases() {
        // v20 は v1 に含まない。アプリが V20 を計算・判定していないため
        // （入力欄も判定プロパティも無い）、閾値を入力できるようにすると
        // 利用者が値を入れたのに何も起きない「黙って効かない」状態になる。
        #expect(Set(MetricKey.allCases) == [.r100, .r50, .d2cm])
    }
}

@Suite("自施設の判定基準の入力検証")
struct CustomProtocolValidatorTests {

    private func validate(name: String = "当院基準", note: String = "",
                          thresholds: [MetricKey: MetricThresholdInput] = [.r50: MetricThresholdInput(within: "4.5")])
        -> Result<CustomProtocolDraft, CustomProtocolValidationError> {
        CustomProtocolValidator.validate(name: name, note: note, thresholds: thresholds)
    }

    // MARK: - 名前・メモ

    @Test("正しい入力は通る")
    func acceptsValidInput() throws {
        let d = try validate().get()
        #expect(d.name == "当院基準")
        #expect(d.note == nil)
        #expect(d.thresholds[.r50]?.within == 4.5)
    }

    @Test("名前が空白のみなら弾く")
    func rejectsBlankName() {
        #expect(validate(name: "   ") == .failure(.nameEmpty))
        #expect(validate(name: "") == .failure(.nameEmpty))
    }

    @Test("名前が 40 文字を超えたら弾く")
    func rejectsLongName() {
        #expect(validate(name: String(repeating: "あ", count: 41)) == .failure(.nameTooLong))
        #expect((try? validate(name: String(repeating: "あ", count: 40)).get()) != nil)
    }

    @Test("メモが 100 文字を超えたら弾く")
    func rejectsLongNote() {
        #expect(validate(note: String(repeating: "あ", count: 101)) == .failure(.noteTooLong))
        #expect((try? validate(note: String(repeating: "あ", count: 100)).get()) != nil)
    }

    @Test("前後の空白は落とす")
    func trimsWhitespace() throws {
        let d = try validate(name: "  当院基準  ", note: "  備考  ").get()
        #expect(d.name == "当院基準")
        #expect(d.note == "備考")
    }

    @Test("空のメモは nil になる")
    func emptyNoteBecomesNil() throws {
        #expect(try validate(note: "   ").get().note == nil)
    }

    // MARK: - 閾値: 段階数

    @Test("閾値 1 つだけ（basis 未指定の許容）は 2 段階として通る")
    func acceptsSingleThreshold() throws {
        let d = try validate(thresholds: [.r100: MetricThresholdInput(within: "1.2")]).get()
        #expect(d.thresholds[.r100]?.within == 1.2)
        #expect(d.thresholds[.r100]?.tolerated == nil)
    }

    @Test("閾値 2 つ（within + tolerated）は 3 段階として通る")
    func acceptsTwoLevelThreshold() throws {
        let d = try validate(thresholds: [.r50: MetricThresholdInput(within: "4.5", tolerated: "5.5")]).get()
        #expect(d.thresholds[.r50]?.within == 4.5)
        #expect(d.thresholds[.r50]?.tolerated == 5.5)
    }

    @Test("すべて空欄の指標は結果に含まれない")
    func emptyMetricIsOmitted() throws {
        let d = try validate(thresholds: [
            .r50: MetricThresholdInput(within: "4.5"),
            .d2cm: MetricThresholdInput(within: "", tolerated: "")
        ]).get()
        #expect(d.thresholds[.d2cm] == nil)
        #expect(d.thresholds.count == 1)
    }

    @Test("すべての閾値が空の基準は保存できない")
    func rejectsAllEmpty() {
        #expect(validate(thresholds: [:]) == .failure(.noThresholds))
        #expect(validate(thresholds: [.r50: MetricThresholdInput()]) == .failure(.noThresholds))
    }

    @Test("「基準内」が空欄で「許容」だけ入っている場合は弾く")
    func rejectsToleratedWithoutWithin() {
        let result = validate(thresholds: [.r50: MetricThresholdInput(within: "", tolerated: "5.5")])
        #expect(result == .failure(.toleratedWithoutWithin(.r50)))
    }

    // MARK: - 閾値: 範囲

    @Test("R100% / R50% の閾値が範囲外なら、その指標を指すエラーで弾く")
    func rejectsRatioOutOfRange() {
        #expect(validate(thresholds: [.r100: MetricThresholdInput(within: "0")])
            == .failure(.thresholdOutOfRange(.r100)))
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "20.1")])
            == .failure(.thresholdOutOfRange(.r50)))
    }

    @Test("D2cm の閾値が範囲外なら、その指標を指すエラーで弾く")
    func rejectsPercentOutOfRange() {
        #expect(validate(thresholds: [.d2cm: MetricThresholdInput(within: "0")])
            == .failure(.thresholdOutOfRange(.d2cm)))
        #expect(validate(thresholds: [.d2cm: MetricThresholdInput(within: "200.1")])
            == .failure(.thresholdOutOfRange(.d2cm)))
    }

    @Test("範囲外エラーは指標を取り違えない（r50 の範囲外が r100 を指さない）")
    func rangeErrorDoesNotConfuseMetrics() {
        let result = validate(thresholds: [.r50: MetricThresholdInput(within: "20.1")])
        #expect(result == .failure(.thresholdOutOfRange(.r50)))
        #expect(result != .failure(.thresholdOutOfRange(.r100)))
    }

    @Test("境界ちょうどの値は通る")
    func acceptsBoundaryValues() throws {
        #expect((try? validate(thresholds: [.r100: MetricThresholdInput(within: "0.1")]).get()) != nil)
        #expect((try? validate(thresholds: [.r100: MetricThresholdInput(within: "20")]).get()) != nil)
        #expect((try? validate(thresholds: [.d2cm: MetricThresholdInput(within: "0.1")]).get()) != nil)
        #expect((try? validate(thresholds: [.d2cm: MetricThresholdInput(within: "200")]).get()) != nil)
    }

    @Test("無限大と巨大な指数表記を弾く")
    func rejectsNonFinite() {
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "inf")])
            == .failure(.thresholdOutOfRange(.r50)))
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "1e309")])
            == .failure(.thresholdOutOfRange(.r50)))
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "4.5", tolerated: "inf")])
            == .failure(.thresholdOutOfRange(.r50)))
    }

    @Test("tolerated が within 以下なら、その指標を指すエラーで弾く")
    func rejectsToleratedNotGreaterThanWithin() {
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "4.5", tolerated: "4.5")])
            == .failure(.toleratedNotGreaterThanWithin(.r50)))
        #expect(validate(thresholds: [.r50: MetricThresholdInput(within: "4.5", tolerated: "4.0")])
            == .failure(.toleratedNotGreaterThanWithin(.r50)))
    }

    @Test("複数指標を同時に検証できる")
    func acceptsMultipleMetrics() throws {
        let d = try validate(thresholds: [
            .r100: MetricThresholdInput(within: "1.2", tolerated: "1.5"),
            .r50:  MetricThresholdInput(within: "4.5", tolerated: "5.5"),
            .d2cm: MetricThresholdInput(within: "60")
        ]).get()
        #expect(d.thresholds.count == 3)
    }

    // MARK: - 数値版（取り込み時の検証に使う）

    @Test("数値版: 正しい入力は通る")
    func numericAcceptsValidInput() throws {
        let d = try CustomProtocolValidator.validate(
            name: "当院基準", note: "備考",
            thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: 5.5)]).get()
        #expect(d.name == "当院基準")
        #expect(d.note == "備考")
        #expect(d.thresholds[.r50] == MetricThreshold(within: 4.5, tolerated: 5.5))
    }

    @Test("数値版: 範囲外の巨大な閾値（1e100）を、その指標を指すエラーで弾く")
    func numericRejectsHugeThreshold() {
        let result = CustomProtocolValidator.validate(
            name: "n", note: nil, thresholds: [.r50: MetricThreshold(within: 1e100, tolerated: nil)])
        #expect(result == .failure(.thresholdOutOfRange(.r50)))
    }

    @Test("数値版: 無限大の閾値を、その指標を指すエラーで弾く")
    func numericRejectsInfiniteThreshold() {
        let result = CustomProtocolValidator.validate(
            name: "n", note: nil, thresholds: [.r100: MetricThreshold(within: .infinity, tolerated: nil)])
        #expect(result == .failure(.thresholdOutOfRange(.r100)))
    }

    @Test("数値版: tolerated が within 以下なら、その指標を指すエラーで弾く")
    func numericRejectsToleratedNotGreater() {
        let result = CustomProtocolValidator.validate(
            name: "n", note: nil, thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: 4.5)])
        #expect(result == .failure(.toleratedNotGreaterThanWithin(.r50)))
    }

    @Test("数値版: 複数指標のうち範囲外の 1 つだけを正しく指す")
    func numericPointsToCorrectMetricAmongMultiple() {
        let result = CustomProtocolValidator.validate(
            name: "n", note: nil, thresholds: [
                .r100: MetricThreshold(within: 1.2, tolerated: nil),
                .d2cm: MetricThreshold(within: 300, tolerated: nil) // 範囲外
            ])
        #expect(result == .failure(.thresholdOutOfRange(.d2cm)))
    }

    @Test("数値版: 閾値が空なら弾く")
    func numericRejectsEmptyThresholds() {
        let result = CustomProtocolValidator.validate(name: "n", note: nil, thresholds: [:])
        #expect(result == .failure(.noThresholds))
    }

    @Test("数値版: note が nil でも通る")
    func numericAllowsNilNote() throws {
        let d = try CustomProtocolValidator.validate(
            name: "n", note: nil, thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: nil)]).get()
        #expect(d.note == nil)
    }

    // MARK: - メッセージ

    // 編集画面は 4 指標 × 2 欄が並ぶため、メッセージが指標名を含まないと
    // 利用者はどの欄を直せばよいか分からない。ここではメッセージが正しい
    // 指標を名指しし、範囲が `range(for:)` から導かれていること
    // （リテラルで別に書かれていないこと）を確認する。

    @Test("rangeDescription は range(for:) の上下限をそのまま反映する")
    func rangeDescriptionReflectsRangeBounds() {
        #expect(CustomProtocolValidator.rangeDescription(for: .r100) == "0.1〜20")
        #expect(CustomProtocolValidator.rangeDescription(for: .r50) == "0.1〜20")
        #expect(CustomProtocolValidator.rangeDescription(for: .d2cm) == "0.1〜200")
    }

    @Test("範囲外エラーのメッセージは指標名と range(for:) 由来の範囲を含む")
    func rangeOutOfRangeMessageIncludesMetricAndRange() {
        for key in MetricKey.allCases {
            let message = String(localized: CustomProtocolValidationError.thresholdOutOfRange(key).message)
            #expect(message.contains(key.displayName), "\(key) の表示名を含まない: \(message)")
            #expect(message.contains(CustomProtocolValidator.rangeDescription(for: key)),
                    "\(key) の範囲を含まない（リテラル埋め込みの疑い）: \(message)")
        }
    }

    @Test("範囲外エラーのメッセージは他の指標名を含まない（取り違えの検出）")
    func rangeOutOfRangeMessageDoesNotMentionOtherMetrics() {
        let message = String(localized: CustomProtocolValidationError.thresholdOutOfRange(.r50).message)
        #expect(!message.contains(MetricKey.d2cm.displayName))
        #expect(!message.contains(MetricKey.r100.displayName))
    }

    @Test("tolerated 関連のエラーメッセージも該当指標名を含む")
    func toleratedErrorMessagesIncludeMetricName() {
        let withoutWithin = String(localized: CustomProtocolValidationError.toleratedWithoutWithin(.r100).message)
        #expect(withoutWithin.contains(MetricKey.r100.displayName))

        let notGreater = String(localized: CustomProtocolValidationError.toleratedNotGreaterThanWithin(.d2cm).message)
        #expect(notGreater.contains(MetricKey.d2cm.displayName))
    }
}
