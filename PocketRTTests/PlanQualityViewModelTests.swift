import Testing
import Foundation
@testable import PocketRT

@Suite("PlanQualityViewModel")
struct PlanQualityViewModelTests {

    /// ブリーフ Step 5 の基準入力（RTOG 0915、全指標が Per protocol となる例）。
    private func makeBaselineVM() -> PlanQualityViewModel {
        let vm = PlanQualityViewModel()
        vm.tvText = "22.0"
        vm.rxText = "48.0"
        vm.fractionsText = "4"
        vm.pivText = "24.0"
        vm.tvPIVText = "18.0"
        vm.v50Text = "90.0"
        vm.dmaxText = "60.0"
        vm.d2Text = "52.0"
        vm.d50Text = "48.0"
        vm.d98Text = "45.0"
        vm.d2cmText = "24.0"
        vm.selectedProtocol = .builtIn(.rtog0915)
        return vm
    }

    @Test("基準入力：全指標が手計算どおりに算出される")
    func baselineIndices() {
        let vm = makeBaselineVM()

        #expect(vm.ciRTOG != nil)
        #expect(abs(vm.ciRTOG! - 24.0 / 22.0) < 0.0001)

        #expect(vm.ciPaddick != nil)
        #expect(abs(vm.ciPaddick! - 324.0 / 528.0) < 0.0001)

        #expect(vm.hiRTOG != nil)
        #expect(abs(vm.hiRTOG! - 1.25) < 0.0001)

        #expect(vm.hiICRU83 != nil)
        #expect(abs(vm.hiICRU83! - 7.0 / 48.0) < 0.0001)

        #expect(vm.r50Value != nil)
        #expect(abs(vm.r50Value! - 90.0 / 22.0) < 0.0001)

        #expect(vm.giPaddick != nil)
        #expect(abs(vm.giPaddick! - 3.75) < 0.0001)

        #expect(vm.d2cmValue != nil)
        #expect(abs(vm.d2cmValue! - 50.0) < 0.0001)

        #expect(vm.issues.isEmpty)
        #expect(vm.judgementBlockedReason == nil)
        #expect(vm.r100Deviation == .perProtocol)
        #expect(vm.r50Deviation == .perProtocol)
        #expect(vm.d2cmDeviation == .perProtocol)
    }

    @Test("分割数が選択プロトコルと一致しないと判定できない（RTOG 0915 は 1 分割と 4 分割）")
    func fractionsOutsideProtocolRangeBlocksJudgement() {
        let vm = makeBaselineVM()
        vm.fractionsText = "5"
        #expect(vm.judgementBlockedReason != nil)
    }

    @Test("RTOG 0915 は 2 分割と 3 分割を一致としない", arguments: [2, 3])
    func rtog0915RejectsUnstudiedFractionCounts(n: Int) {
        // 0915 が検討したのは 34 Gy/1 Fr と 48 Gy/4 Fr の 2 群だけで、
        // 2 分割と 3 分割は試験が扱っていない。範囲（1...4）で持っていた頃は
        // 「プロトコルに一致」と表示していた。
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0915)
        vm.fractionsText = "\(n)"
        #expect(vm.judgementBlockedReason != nil, "\(n) 分割が一致として通っている")
        #expect(vm.judgementBlockKind == .outsideProtocolScope,
                "\(n) 分割は入力不足ではなく適用範囲外に分類されるべき")
    }

    @Test("RTOG 0915 は検討した 2 つの線量分割を一致とする",
          arguments: [(n: 1, rx: "34.0"), (n: 4, rx: "48.0")])
    func rtog0915AcceptsStudiedSchedules(schedule: (n: Int, rx: String)) {
        // 第 1 群 34 Gy/1 Fr、第 2 群 48 Gy/4 Fr
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0915)
        vm.fractionsText = "\(schedule.n)"
        vm.rxText = schedule.rx
        #expect(vm.judgementBlockedReason == nil,
                "\(schedule.rx) Gy / \(schedule.n) Fr が弾かれている")
    }

    @Test("RTOG 0915 は分割数が合っても検討外の線量を一致としない",
          arguments: [(n: 1, rx: "20.0"), (n: 1, rx: "48.0"), (n: 4, rx: "40.0")])
    func rtog0915RejectsUnstudiedDose(schedule: (n: Int, rx: String)) {
        // 分割数と線量を別々に見ていると、どの群にも無い組み合わせが通る
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0915)
        vm.fractionsText = "\(schedule.n)"
        vm.rxText = schedule.rx
        #expect(vm.judgementBlockedReason != nil,
                "\(schedule.rx) Gy / \(schedule.n) Fr が一致として通っている")
        #expect(vm.judgementBlockKind == .outsideProtocolScope)
    }

    @Test("RTOG 0813 は 5 分割のみを一致とする", arguments: [1, 4, 6])
    func rtog0813AcceptsOnlyFiveFractions(n: Int) {
        // 0813 の線量漸増は 1 回線量（10〜12 Gy）で行われ、分割数は 5 で固定
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0813)
        vm.fractionsText = "\(n)"
        #expect(vm.judgementBlockedReason != nil, "\(n) 分割が一致として通っている")
    }

    @Test("RTOG 0813 は 5 分割で 50〜60 Gy を一致とする",
          arguments: ["50.0", "55.0", "60.0"])
    func rtog0813AcceptsStudiedDoseRange(rx: String) {
        // 10〜12 Gy/回 × 5 分割
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0813)
        vm.fractionsText = "5"
        vm.rxText = rx
        #expect(vm.judgementBlockedReason == nil, "\(rx) Gy / 5 Fr が弾かれている")
    }

    @Test("RTOG 0813 は 5 分割でも範囲外の線量を一致としない",
          arguments: ["40.0", "70.0"])
    func rtog0813RejectsDoseOutsideStudiedRange(rx: String) {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0813)
        vm.fractionsText = "5"
        vm.rxText = rx
        #expect(vm.judgementBlockedReason != nil, "\(rx) Gy / 5 Fr が一致として通っている")
        #expect(vm.judgementBlockKind == .outsideProtocolScope)
    }

    @Test("線量が合わない理由は、検討された線量分割を示す")
    func doseMismatchReasonNamesStudiedSchedule() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0915)
        vm.fractionsText = "4"
        vm.rxText = "40.0"
        let reason = vm.judgementBlockedReason ?? ""
        #expect(reason.contains("48"), "検討された線量が示されていない")
        #expect(reason.contains("40"), "入力値が示されていない")
    }

    @Test("判定できない理由が、何分割なら一致するのかを示す")
    func blockedReasonNamesExpectedFractions() {
        // 「一致しません」だけでは、入力を直せばよいのか別のプロトコルを
        // 選ぶべきなのかが判断できない
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0915)
        vm.fractionsText = "3"
        let reason = vm.judgementBlockedReason ?? ""
        #expect(reason.contains("1"))
        #expect(reason.contains("4"))
        #expect(reason.contains("3"))
    }

    @Test("PTV 体積が判定表の範囲外だと判定できない（範囲は 1.8〜163.0 cc）")
    func ptvVolumeOutsideTableRangeBlocksJudgement() {
        let vm = makeBaselineVM()
        vm.tvText = "200"
        #expect(vm.judgementBlockedReason != nil)
    }

    @Test("PTV 体積が表の範囲外は「公表プロトコルの適用範囲外」に分類される")
    func ptvVolumeOutsideTableRangeIsOutsideProtocolScope() {
        let vm = makeBaselineVM()
        vm.tvText = "200"
        #expect(vm.judgementBlockKind == .outsideProtocolScope)
    }

    @Test("プロトコル未選択は「入力が足りない」に分類される")
    func noProtocolSelectedIsIncompleteInput() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(vm.judgementBlockKind == .incompleteInput)
    }

    // MARK: - 利用者定義プロトコル（.custom）

    /// `.custom` は id しか持たない（値のコピーではない。外部レビュー指摘により
    /// 変更。削除・編集への追随のため）。テストでは `vm.customProtocols` に登録
    /// してから `vm.selectedProtocol = .custom(id)` で選択する 2 段階が必要になる。
    private func select(_ vm: PlanQualityViewModel, _ p: CustomProtocol) {
        vm.customProtocols = [p]
        vm.selectedProtocol = .custom(p.id)
    }

    private func customProtocol(
        id: String = UUID().uuidString, name: String = "当院基準",
        thresholds: [MetricKey: MetricThreshold] = [.r50: MetricThreshold(within: 4.5, tolerated: nil)]
    ) -> CustomProtocol {
        CustomProtocol(id: id, name: name, note: nil, thresholds: thresholds,
                       createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test(".custom では線量分割の一致検査が働かない（検討された線量分割という概念が無い）")
    func customProtocolSkipsStudiedScheduleCheck() {
        // RTOG 0915 なら弾かれる分割数（2 分割）でも、.custom には
        // 検討された線量分割という概念そのものが無いので、これを理由に
        // 判定がブロックされてはいけない。
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        vm.fractionsText = "2"
        #expect(vm.judgementBlockedReason == nil,
                "線量分割の一致検査（RTOG 用）が .custom に対して働いている: \(vm.judgementBlockedReason ?? "")")
        #expect(vm.selectedProtocol.studiedSchedules == nil)
    }

    // MARK: - 選択中の基準が削除・編集された場合（外部レビューで検出した実バグ）

    @Test("選択中の基準を削除すると（customProtocols から消えると）、判定が出なくなる")
    func deletingSelectedCustomProtocolStopsJudgement() {
        let vm = makeBaselineVM()
        let p = customProtocol(name: "厳しい基準", thresholds: [.r50: MetricThreshold(within: 3.0, tolerated: nil)])
        select(vm, p)
        #expect(vm.r50Deviation == .major, "前提: 削除前は判定が出ている")

        // 削除 = customProtocols からその id を取り除く。selectedProtocol は
        // 触らない（id をそのまま持ち続ける。これが値ではなく id を持つ設計の要）。
        vm.customProtocols = []

        #expect(vm.r50Deviation == nil, "削除したプロトコルの閾値で判定が出続けている")
        #expect(vm.d2cmDeviation == nil)
        #expect(vm.r100Deviation == nil)
    }

    @Test("選択中の基準を削除すると、なぜ判定が出ないのかが判定パネルから分かる（黙って .none 扱いにしない）")
    func deletingSelectedCustomProtocolExplainsWhy() {
        let vm = makeBaselineVM()
        let p = customProtocol()
        select(vm, p)
        vm.customProtocols = []

        #expect(vm.judgementBlockedReason != nil, "削除されたのに判定がブロックされていない")
        #expect(vm.judgementBlockKind == .selectedCustomProtocolDeleted)
        // .incompleteInput（入力を足せば解決する）と区別する。選び直すしかないため。
        #expect(vm.judgementBlockKind != .incompleteInput)
        // 見出しの表示名も「もう無い」ことが分かる文言にする（元の名前を出し続けない）。
        #expect(vm.selectedProtocolDisplayName != p.name)
    }

    @Test("選択中の基準を編集すると（customProtocols の内容が変わると）、判定は新しい閾値で行われる")
    func editingSelectedCustomProtocolUpdatesJudgement() {
        // makeBaselineVM: r50Value ≈ 4.09（v50=90.0 / tv=22.0）
        let vm = makeBaselineVM()
        let original = customProtocol(name: "編集前", thresholds: [.r50: MetricThreshold(within: 10.0, tolerated: nil)])
        select(vm, original)
        #expect(vm.r50Deviation == .perProtocol, "前提: 編集前は緩い閾値（10.0）で per protocol")

        // 編集 = 同じ id で内容だけ変える（CustomProtocolStoreModel.update と同じ形）。
        var edited = original
        edited.name = "編集後"
        edited.thresholds = [.r50: MetricThreshold(within: 3.0, tolerated: nil)]
        vm.customProtocols = [edited]

        #expect(vm.r50Deviation == .major,
                "編集前の閾値（10.0）のまま判定されている。id は同じでも内容の変更が反映されていない")
        #expect(vm.selectedProtocolDisplayName == "編集後", "名前の変更も反映されていない")
    }

    @Test(".builtIn と .none は customProtocols の変化の影響を受けない")
    func builtInAndNoneUnaffectedByCustomProtocolsChanges() {
        let vm = makeBaselineVM() // .builtIn(.rtog0915)
        vm.customProtocols = [customProtocol()]
        #expect(vm.r50Deviation == .perProtocol, ".builtIn の判定が customProtocols の内容に影響されている")
        vm.customProtocols = []
        #expect(vm.r50Deviation == .perProtocol)

        vm.selectedProtocol = .none
        vm.customProtocols = [customProtocol()]
        #expect(vm.judgementBlockedReason != nil)
        #expect(vm.judgementBlockKind == .incompleteInput, ".none が customProtocols の内容に影響されている")
    }

    // MARK: - .custom の閾値が実際の判定に使われる（Task 5.5・判定の配線）

    @Test("RTOG の閾値なら per protocol になる値でも、.custom の（より厳しい）閾値では major になる")
    func customProtocolThresholdOverridesRTOGValue() {
        // makeBaselineVM: v50=90.0, tv=22.0 → r50Value ≈ 4.09。
        // RTOG 0915（PTV 22.0cc）の r50None は 4.5 なので、RTOG の数値で
        // 判定されていれば per protocol になる値。.custom の within を
        // 3.0（RTOG より厳しい）にして、実際に .custom の閾値で判定されて
        // いることを確認する。RTOG の数値が使われていれば、この値は
        // per protocol になってしまうはず。
        let vm = makeBaselineVM()
        let strict = CustomProtocol(id: "c2", name: "厳しい基準", note: nil,
                                    thresholds: [.r50: MetricThreshold(within: 3.0, tolerated: nil)],
                                    createdAt: Date(timeIntervalSince1970: 0))
        select(vm, strict)
        #expect(vm.r50Value != nil)
        #expect(vm.r50Value! > 3.0, "テスト設計の前提が崩れている（r50Value が within を超えていない）")
        #expect(vm.r50Deviation == .major,
                "RTOG の数値（r50None=4.5）のままなら per protocol になるはずの値。.custom の閾値（3.0）が使われていない")
    }

    @Test(".custom の tolerated ありは 3 段階で判定される")
    func customProtocolThreeStageJudgement() {
        // r50Value ≈ 4.09（v50=90.0 / tv=22.0）を within と tolerated の間に収める
        let vm = makeBaselineVM()
        let p = CustomProtocol(id: "c3", name: "3 段階基準", note: nil,
                               thresholds: [.r50: MetricThreshold(within: 4.0, tolerated: 4.2)],
                               createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        let v = vm.r50Value!
        #expect(v > 4.0 && v < 4.2, "テスト設計の前提が崩れている: r50Value=\(v)")
        #expect(vm.r50Deviation == .minor)
    }

    @Test(".custom で閾値を定めていない指標は nil を返す（0 や基準内にしない）")
    func customProtocolMissingThresholdYieldsNilNotZero() {
        let vm = makeBaselineVM()
        // R50% だけを定めた基準（施設が R100% / D2cm を定めていない想定）
        let p = CustomProtocol(id: "c4", name: "R50のみ規定", note: nil,
                               thresholds: [.r50: MetricThreshold(within: 10.0, tolerated: nil)],
                               createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        #expect(vm.r50Deviation != nil, "定めている指標まで nil になっている")
        #expect(vm.r100Deviation == nil, "閾値の無い指標が判定されてしまっている")
        #expect(vm.d2cmDeviation == nil, "閾値の無い指標が判定されてしまっている")
        #expect(vm.isThresholdUnconfigured(.r100))
        #expect(vm.isThresholdUnconfigured(.d2cm))
        #expect(!vm.isThresholdUnconfigured(.r50))
    }

    @Test("isThresholdUnconfigured は .builtIn と .none では常に false")
    func isThresholdUnconfiguredFalseForBuiltInAndNone() {
        let vm = makeBaselineVM()
        for key in MetricKey.allCases {
            #expect(!vm.isThresholdUnconfigured(key))
        }
        vm.selectedProtocol = .none
        for key in MetricKey.allCases {
            #expect(!vm.isThresholdUnconfigured(key))
        }
    }

    // MARK: - customThresholdSummary（判定パネルに登録した閾値を出す。レビュー指摘で追加）

    @Test("customThresholdSummary は定めている指標だけを含む（未設定の指標が 0.0 などで現れない）")
    func customThresholdSummaryOnlyIncludesConfiguredMetrics() {
        let vm = makeBaselineVM()
        // R50% のみ規定。R100% / D2cm は未設定
        let p = CustomProtocol(id: "c6", name: "R50のみ規定", note: nil,
                               thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: nil)],
                               createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        let summary = vm.customThresholdSummary
        #expect(summary.contains("R50%"))
        #expect(!summary.contains("R100%"), "未設定の指標が現れている")
        #expect(!summary.contains("D2cm"), "未設定の指標が現れている")
        #expect(!summary.contains("0.0"), "未設定の指標が 0.0 などで埋められている")
    }

    @Test("customThresholdSummary は tolerated がある指標では 2 つの閾値を出す")
    func customThresholdSummaryShowsBothThresholdsWhenToleratedPresent() {
        let vm = makeBaselineVM()
        let p = CustomProtocol(id: "c7", name: "3段階基準", note: nil,
                               thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: 5.5)],
                               createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        let summary = vm.customThresholdSummary
        #expect(summary.contains("4.5"), "within が出ていない: \(summary)")
        #expect(summary.contains("5.5"), "tolerated が出ていない（3 段階なのに 1 つしか示していない）: \(summary)")
    }

    @Test("customThresholdSummary は tolerated が無い指標では 1 つの閾値だけを出す")
    func customThresholdSummaryShowsOnlyWithinWhenToleratedAbsent() {
        let vm = makeBaselineVM()
        let p = CustomProtocol(id: "c8", name: "2段階基準", note: nil,
                               thresholds: [.d2cm: MetricThreshold(within: 60.0, tolerated: nil)],
                               createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        let summary = vm.customThresholdSummary
        #expect(summary.contains("60"), "within が出ていない: \(summary)")
        // tolerated が無いので "/" で区切られた 2 つ目の数値が無いこと
        #expect(!summary.contains("/"), "tolerated が無いのに 2 つ目の閾値が出ている: \(summary)")
    }

    @Test("customThresholdSummary は閾値が 1 つも無い基準では空文字列になる")
    func customThresholdSummaryIsEmptyWhenNoThresholds() {
        // 保存できないはずの基準（CustomProtocolValidator が弾く）だが、
        // 万一この状態に到達しても空を返すことを念のため確認する。
        let vm = makeBaselineVM()
        let p = CustomProtocol(id: "c9", name: "空の基準", note: nil,
                               thresholds: [:], createdAt: Date(timeIntervalSince1970: 0))
        select(vm, p)
        #expect(vm.customThresholdSummary.isEmpty)
    }

    @Test("customThresholdSummary は .builtIn / .none では空文字列（RTOG の許容値表示と同時に出ない）")
    func customThresholdSummaryEmptyForBuiltInAndNone() {
        let vm = makeBaselineVM() // .builtIn(.rtog0915)
        #expect(vm.customThresholdSummary.isEmpty)
        #expect(vm.limits != nil, "対照: .builtIn では limits 側が値を持つ")

        vm.selectedProtocol = .none
        #expect(vm.customThresholdSummary.isEmpty)
    }

    @Test(".custom の段階名は customDisplayName（基準内/基準をやや超える/基準を超える）に対応する")
    func customProtocolDeviationMapsToCustomDisplayName() {
        // ConformityCriteriaTests で customDisplayName 自体は固定済み。ここでは
        // .custom の判定結果（DeviationLevel）が実際にその表示名系列に載る
        // 値であることを、ViewModel 経由で確かめる。
        let vm = makeBaselineVM()
        let strict = CustomProtocol(id: "c5", name: "厳しい基準", note: nil,
                                    thresholds: [.r50: MetricThreshold(within: 3.0, tolerated: nil)],
                                    createdAt: Date(timeIntervalSince1970: 0))
        select(vm, strict)
        #expect(vm.r50Deviation == .major)
        #expect(vm.r50Deviation?.customDisplayName == "基準を超える")
    }

    @Test(".builtIn の判定結果は判定配線後も変わらない（境界値、RTOG 0915・PTV 22.0cc）")
    func builtInDeviationUnchangedAtBoundaryAfterWiring() {
        let vm = makeBaselineVM()
        vm.v50Text = "99.0" // r50Value = 99.0 / 22.0 = 4.5 ちょうど（r50None の境界）
        #expect(vm.r50Value != nil)
        #expect(abs(vm.r50Value! - 4.5) < 0.0001)
        #expect(vm.r50Deviation == .minor,
                "境界ちょうどは per protocol ではなく minor のはず（表記が < のため。ConformityCriteria の規約）")
    }

    // MARK: - limits（RTOG の許容値）は .builtIn 以外で必ず nil（唯一の防波堤）

    @Test(".builtIn を選び PTV 体積が表の範囲内なら limits は値を返す")
    func limitsReturnsValueForBuiltInWithinRange() {
        let vm = makeBaselineVM() // tv = 22.0（表の範囲内）、selectedProtocol = .builtIn(.rtog0915)
        #expect(vm.limits != nil)
    }

    @Test(".custom を選ぶと、PTV 体積が RTOG の表の範囲内であっても limits は nil")
    func limitsIsNilForCustomEvenWithinRTOGRange() {
        // PTV 体積を範囲外にすると、別の理由（範囲外）で nil になり、
        // .custom を理由に止まっているのか判別できない。範囲内（22.0）の
        // ままにするのが本体（team-lead 指摘）。
        let vm = makeBaselineVM() // tv = 22.0（RTOG の表の範囲内）
        select(vm, customProtocol())
        #expect(vm.limits == nil,
                ".custom を選んでいるのに RTOG の許容値が漏れている（許容値表示に RTOG の数値が出る事故）")
    }

    @Test(".none を選ぶと limits は nil")
    func limitsIsNilForNone() {
        let vm = makeBaselineVM() // tv = 22.0（RTOG の表の範囲内）
        vm.selectedProtocol = .none
        #expect(vm.limits == nil)
    }

    // MARK: - attributionNote（判定パネルの帰属）— 判定と帰属は一体、2 つの文言は同時に出ない

    @Test(".builtIn では公表プロトコルの帰属になる")
    func attributionNoteIsPublishedProtocolForBuiltIn() {
        let vm = makeBaselineVM() // selectedProtocol = .builtIn(.rtog0915)
        #expect(vm.attributionNote == .publishedProtocol)
    }

    @Test(".custom では利用者定義の帰属になる")
    func attributionNoteIsUserDefinedForCustom() {
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        #expect(vm.attributionNote == .userDefined)
    }

    @Test(".none では帰属を出さない")
    func attributionNoteIsNoneWhenNoProtocolSelected() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(vm.attributionNote == .none)
    }

    @Test("attributionNote は 3 状態のうちちょうど 1 つで、公表プロトコル用と利用者定義用の文言が同時に出ることはない")
    func attributionNoteIsMutuallyExclusive() {
        // AttributionNote は selectedProtocol から一意に決まる 1 つの enum なので、
        // .publishedProtocol と .userDefined が同時に真になることは型として無い。
        // ここでは 3 ケースそれぞれで、他の 2 つと異なることを網羅的に確認する。
        let vm = makeBaselineVM()

        vm.selectedProtocol = .builtIn(.rtog0915)
        #expect(vm.attributionNote == .publishedProtocol)
        #expect(vm.attributionNote != .userDefined)
        #expect(vm.attributionNote != .none)

        select(vm, customProtocol())
        #expect(vm.attributionNote == .userDefined)
        #expect(vm.attributionNote != .publishedProtocol)
        #expect(vm.attributionNote != .none)

        vm.selectedProtocol = .none
        #expect(vm.attributionNote == .none)
        #expect(vm.attributionNote != .publishedProtocol)
        #expect(vm.attributionNote != .userDefined)
    }

    @Test(".custom の帰属は判定がブロックされていても（矛盾入力中でも）常時出る（折りたたまない）")
    func attributionNoteForCustomIsAlwaysPresentEvenWhenBlocked() {
        // 仕様 §3.3「常時出す。折りたたまない」。judgementBlockedReason の
        // 有無（issues の矛盾等）に関わらず、選択が .custom である限り
        // attributionNote は .userDefined のまま変わらないことを確認する。
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        vm.tvPIVText = "30.0" // PTV∩PIV が PTV を超える矛盾入力（issues を発生させる）
        #expect(!vm.issues.isEmpty)
        #expect(vm.judgementBlockedReason != nil, "矛盾入力なので判定はブロックされているはず")
        #expect(vm.attributionNote == .userDefined, "判定がブロックされていても帰属は消えてはいけない")
    }

    @Test("PTV∩PIV が PTV を超える矛盾入力は issues を報告し判定を止める")
    func tvPIVExceedsTVBlocksJudgement() {
        let vm = makeBaselineVM()
        vm.tvPIVText = "30.0"
        #expect(vm.issues.contains(.tvPIVExceedsTV))
        #expect(vm.judgementBlockedReason != nil)
    }

    @Test("V50% が未入力でも R50%・GI 以外の指標は表示され続ける")
    func missingV50OnlyAffectsDependentIndices() {
        let vm = makeBaselineVM()
        vm.v50Text = ""
        #expect(vm.r50Value == nil)
        #expect(vm.giPaddick == nil)
        #expect(vm.ciRTOG != nil)
        #expect(vm.hiRTOG != nil)
    }

    @Test("プロトコル「判定しない」では指標は算出されるが判定は出さない")
    func noProtocolSelectedBlocksJudgementButKeepsIndices() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(vm.judgementBlockedReason != nil)
        #expect(vm.ciRTOG != nil)
    }

    @Test("\"inf\" は正の数値として受け付けない（TPS からのペースト対策）")
    func infTextIsRejected() {
        let vm = makeBaselineVM()
        vm.tvText = "inf"
        #expect(vm.tv == nil)
        #expect(vm.ciRTOG == nil)
    }

    @Test("\"1e309\" は Double パース時に +∞ になるため受け付けない")
    func overflowTextIsRejected() {
        let vm = makeBaselineVM()
        vm.tvText = "1e309"
        #expect(vm.tv == nil)
        #expect(vm.ciRTOG == nil)
    }

    // MARK: - 頭部定位照射（Shaw 1993, .builtIn(.cranialSRS)）— D4 Task 1

    /// 頭部定位照射用の基準入力。MDPD = 1.5（per protocol）、PITV = 1.5（per protocol）
    /// になる値。PTV 体積・分割数は RTOG 0813 / 0915 の表の範囲外にわざと外して、
    /// 頭部定位照射がそれらに依存しないことも一緒に確かめられるようにする。
    private func makeCranialVM() -> PlanQualityViewModel {
        let vm = PlanQualityViewModel()
        vm.tvText = "0.5"       // RTOG 表の範囲（1.8〜163.0 cc）の外
        vm.rxText = "20.0"
        vm.fractionsText = "1"  // 0813(5) にも 0915(1 or 4) にも該当しうるが検査自体が働かない
        vm.pivText = "0.75"     // ciRTOG = 0.75 / 0.5 = 1.5 (PITV)
        vm.dmaxText = "30.0"    // hiRTOG = 30.0 / 20.0 = 1.5 (MDPD)
        vm.selectedProtocol = .builtIn(.cranialSRS)
        return vm
    }

    @Test("頭部定位照射: MDPD は hiRTOG と同じ値を Shaw 1993 の許容値で判定する")
    func cranialMDPDUsesHiRTOGValue() {
        let vm = makeCranialVM()
        #expect(vm.hiRTOG != nil)
        #expect(abs(vm.hiRTOG! - 1.5) < 0.0001)
        #expect(vm.mdpdDeviation == .perProtocol)
    }

    @Test("頭部定位照射: PITV は ciRTOG と同じ値を Shaw 1993 の許容値（両側）で判定する")
    func cranialPITVUsesCiRTOGValue() {
        let vm = makeCranialVM()
        #expect(vm.ciRTOG != nil)
        #expect(abs(vm.ciRTOG! - 1.5) < 0.0001)
        #expect(vm.pitvDeviation == .perProtocol)
    }

    @Test("頭部定位照射: MDPD = 2.0 ちょうどは per protocol（原典が明示的に含む境界）")
    func cranialMDPDExactlyTwoIsPerProtocol() {
        let vm = makeCranialVM()
        vm.dmaxText = "40.0" // hiRTOG = 40.0 / 20.0 = 2.0 ちょうど
        #expect(abs(vm.hiRTOG! - 2.0) < 0.0001)
        #expect(vm.mdpdDeviation == .perProtocol, "MDPD = 2.0 ちょうどは per protocol のはず（minor になっていたら inclusive フラグの渡し忘れ）")
    }

    @Test("頭部定位照射: MDPD = 2.5 ちょうどは major（原典が定めていない境界、安全側）")
    func cranialMDPDExactlyTwoPointFiveIsMajor() {
        let vm = makeCranialVM()
        vm.dmaxText = "50.0" // hiRTOG = 50.0 / 20.0 = 2.5 ちょうど
        #expect(abs(vm.hiRTOG! - 2.5) < 0.0001)
        #expect(vm.mdpdDeviation == .major)
    }

    @Test("頭部定位照射: PITV = 1.0 ちょうどは per protocol（原典が明示的に含む境界）")
    func cranialPITVExactlyOneIsPerProtocol() {
        let vm = makeCranialVM()
        vm.pivText = "0.5" // ciRTOG = 0.5 / 0.5 = 1.0 ちょうど
        #expect(abs(vm.ciRTOG! - 1.0) < 0.0001)
        #expect(vm.pitvDeviation == .perProtocol)
    }

    @Test("頭部定位照射: PITV = 0.9 ちょうどは major（原典が定めていない境界、安全側）")
    func cranialPITVExactlyZeroPointNineIsMajor() {
        let vm = makeCranialVM()
        vm.pivText = "0.45" // ciRTOG = 0.45 / 0.5 = 0.9 ちょうど
        #expect(abs(vm.ciRTOG! - 0.9) < 0.0001)
        #expect(vm.pitvDeviation == .major)
    }

    // MARK: - 許容値キャプション（レビュー指摘: 判定と食い違っていた不等号の修正）
    //
    // 以前は View に "MDPD < %.1f (none)" というリテラルが直接埋め込まれており、
    // 実際の判定（upperNoneIsInclusive: true、2.0 を含む）と不等号が食い違っていた。
    // ViewModel 側に一元化したので、判定バッジとキャプションの表記が一致することを
    // ここで固定する。

    @Test("MDPD キャプション: none 境界が「以下」（含む）と書かれ、「< 2.0」のような排他的表記を含まない")
    func mdpdCaptionStatesInclusiveNoneBoundary() {
        let vm = makeCranialVM()
        let caption = vm.mdpdLimitsCaption
        #expect(caption.contains("2.0 以下"), "MDPD の none 境界（含む）が「以下」と表記されていない: \(caption)")
        #expect(!caption.contains("< 2.0"), "MDPD の none 境界が排他的な不等号（< 2.0）で書かれている。判定（≦ 2.0）と食い違う: \(caption)")
    }

    @Test("MDPD キャプション: minor の上限（major との境界）は排他的表記（未満）で、原典が定めていない境界であることと一致する")
    func mdpdCaptionStatesExclusiveMinorUpperBoundary() {
        let vm = makeCranialVM()
        let caption = vm.mdpdLimitsCaption
        #expect(caption.contains("2.5 未満"), "MDPD の minor 上限（含まない。ちょうど 2.5 は major）が「未満」と表記されていない: \(caption)")
    }

    @Test("頭部定位照射: MDPD = 2.0 ちょうどで、判定バッジ（per protocol）とキャプションの表記が矛盾しない")
    func mdpdBoundaryBadgeMatchesCaptionAtExactlyTwo() {
        let vm = makeCranialVM()
        vm.dmaxText = "40.0" // hiRTOG = 40.0 / 20.0 = 2.0 ちょうど
        #expect(abs(vm.hiRTOG! - 2.0) < 0.0001)
        #expect(vm.mdpdDeviation == .perProtocol, "前提: 判定バッジは per protocol のはず")

        // 判定が per protocol を返す値（2.0）が、キャプションの表記上も
        // per protocol（none）の範囲に入っていることを確認する。
        // 「以下」（含む）でなく「未満」（含まない）と書かれていたら、
        // 2.0 ちょうどの症例でバッジとキャプションが矛盾して見える。
        let caption = vm.mdpdLimitsCaption
        #expect(caption.contains("2.0 以下で none"),
                "判定は per protocol（2.0 を含む）なのに、キャプションの none 境界が含まない表記になっている: \(caption)")
    }

    @Test("PITV キャプション: 下限は「以上」（含む）、上限は「未満」（含まない）の非対称な不等号で none を書く")
    func pitvCaptionStatesAsymmetricNoneBoundary() {
        let vm = makeCranialVM()
        let caption = vm.pitvLimitsCaption
        #expect(caption.contains("1.0 以上"), "PITV の下限（含む）が「以上」と表記されていない: \(caption)")
        #expect(caption.contains("2.0 未満で none"), "PITV の上限（含まない）が「未満」と表記されていない: \(caption)")
    }

    @Test("頭部定位照射: PITV = 1.0 ちょうどで、判定バッジ（per protocol）とキャプションの表記が矛盾しない")
    func pitvBoundaryBadgeMatchesCaptionAtExactlyOne() {
        let vm = makeCranialVM()
        vm.pivText = "0.5" // ciRTOG = 0.5 / 0.5 = 1.0 ちょうど
        #expect(abs(vm.ciRTOG! - 1.0) < 0.0001)
        #expect(vm.pitvDeviation == .perProtocol, "前提: 判定バッジは per protocol のはず")

        let caption = vm.pitvLimitsCaption
        #expect(caption.contains("1.0 以上"),
                "判定は per protocol（1.0 を含む）なのに、キャプションの下限が含まない表記になっている: \(caption)")
    }

    @Test("頭部定位照射: PTV 体積が RTOG の表の範囲外でも判定がブロックされない（仕様 §3.2）")
    func cranialIgnoresRTOGVolumeRange() {
        let vm = makeCranialVM()
        #expect(vm.tv == 0.5, "前提: PTV 体積が RTOG 表の範囲（1.8〜163.0 cc）の外")
        #expect(ConformityCriteria.limits(ptvVolume: 0.5) == nil, "前提: RTOG の表はこの体積を扱わない")
        #expect(vm.judgementBlockedReason == nil, "頭部定位照射は PTV 体積の表範囲に依存しないはず")
        #expect(vm.judgementBlockKind == nil)
    }

    @Test("頭部定位照射: 検討された線量分割という概念が無いので、分割数で判定がブロックされない")
    func cranialIgnoresStudiedScheduleCheck() {
        let vm = makeCranialVM()
        vm.fractionsText = "37" // 0813(5)・0915(1 or 4) のどちらにも該当しない分割数
        #expect(vm.judgementBlockedReason == nil,
                "頭部定位照射は studiedSchedules を持たないので分割数で弾かれてはいけない: \(vm.judgementBlockedReason ?? "")")
        #expect(vm.selectedProtocol.studiedSchedules == [])
    }

    @Test("頭部定位照射: PTV 体積が未入力でも MDPD は判定できる（PITV だけが tv に依存する）")
    func cranialMDPDDoesNotRequirePTVVolume() {
        let vm = makeCranialVM()
        vm.tvText = ""
        #expect(vm.tv == nil)
        #expect(vm.judgementBlockedReason == nil, "頭部定位照射は PTV 体積の入力を判定パネル全体の前提にしない")
        #expect(vm.mdpdDeviation == .perProtocol, "MDPD は dmax と rx だけで計算できるので、tv が無くても判定できるはず")
        #expect(vm.pitvDeviation == nil, "PITV は ciRTOG（piv/tv）に依存するので、tv が無ければ入力待ちで nil")
    }

    @Test("頭部定位照射: RTOG 固有の R100% / R50% / D2cm は判定しない（Shaw 1993 に無い指標）")
    func cranialDoesNotJudgeRTOGSpecificMetrics() {
        let vm = makeCranialVM()
        vm.v50Text = "1.0"
        vm.d2cmText = "10.0"
        #expect(vm.r100Deviation == nil, "R100%（RTOG 0813/0915 固有の許容値）が頭部定位照射で判定されてしまっている")
        #expect(vm.r50Deviation == nil)
        #expect(vm.d2cmDeviation == nil)
    }

    @Test("頭部定位照射: limits（RTOG の表由来の許容値）は常に nil")
    func cranialLimitsIsAlwaysNil() {
        let vm = makeCranialVM()
        #expect(vm.limits == nil, "頭部定位照射で RTOG の許容値が漏れている（誤った数値が判定に使われる事故）")
    }

    @Test("頭部定位照射: 帰属は公表プロトコルとして扱われる")
    func cranialAttributionIsPublishedProtocol() {
        let vm = makeCranialVM()
        #expect(vm.attributionNote == .publishedProtocol)
    }

    // MARK: - isCranialSRSSelected（GI の但し書き・Coverage 未判定の明示等の唯一の表示条件。仕様 §2.5）

    @Test("isCranialSRSSelected: 頭部定位照射を選んでいるときだけ true")
    func isCranialSRSSelectedTrueOnlyForCranial() {
        let vm = makeCranialVM()
        #expect(vm.isCranialSRSSelected)
    }

    @Test("isCranialSRSSelected: 肺 SBRT（RTOG 0915 / 0813）選択時は false（GI の但し書きが誤って出てはいけない）")
    func isCranialSRSSelectedFalseForLungSBRT() {
        let vm915 = makeBaselineVM() // .builtIn(.rtog0915)
        #expect(!vm915.isCranialSRSSelected)

        let vm813 = makeBaselineVM()
        vm813.selectedProtocol = .builtIn(.rtog0813)
        #expect(!vm813.isCranialSRSSelected)
    }

    @Test("isCranialSRSSelected: 未選択（.none）のときは false")
    func isCranialSRSSelectedFalseForNone() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(!vm.isCranialSRSSelected)
    }

    @Test("isCranialSRSSelected: 自施設の基準（.custom）選択時は false")
    func isCranialSRSSelectedFalseForCustom() {
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        #expect(!vm.isCranialSRSSelected)
    }

    // MARK: - isLungSBRTSelected（scopeNote 等、肺 SBRT 固有注記の唯一の表示条件）
    //
    // 欠陥修正: scopeNote は以前 `selectedProtocol.summary != nil` という緩い
    // 条件で表示しており、summary を持つ頭部定位照射にも漏れていた。
    // 表示条件をこのプロパティに集約し、対象範囲をここで固定する。

    @Test("isLungSBRTSelected: RTOG 0915 選択時は true")
    func isLungSBRTSelectedTrueForRTOG0915() {
        let vm = makeBaselineVM() // .builtIn(.rtog0915)
        #expect(vm.isLungSBRTSelected)
    }

    @Test("isLungSBRTSelected: RTOG 0813 選択時は true")
    func isLungSBRTSelectedTrueForRTOG0813() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0813)
        #expect(vm.isLungSBRTSelected)
    }

    @Test("isLungSBRTSelected: 頭部定位照射選択時は false（今回の欠陥: 以前はここが漏れて true 相当になっていた）")
    func isLungSBRTSelectedFalseForCranial() {
        let vm = makeCranialVM()
        #expect(!vm.isLungSBRTSelected)
    }

    @Test("isLungSBRTSelected: 自施設の基準（.custom）選択時は false")
    func isLungSBRTSelectedFalseForCustom() {
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        #expect(!vm.isLungSBRTSelected)
    }

    // MARK: - hasAnyJudgement（判定カードの見た目をプロトコル間で揃える）

    @Test("hasAnyJudgement: 肺 SBRT と頭部定位照射で、何も判定していない状態の扱いが揃う")
    func hasAnyJudgementConsistentAcrossProtocols() {
        // 以前は判定カードだけが judgementBlockKind == .incompleteInput を見ており、
        // 肺 SBRT（PTV 体積が無いと表を引けず止まる）は灰色、頭部定位照射
        // （止まる条件を持たず行ごとに「入力待ち」）は通常の背景、と
        // 同じ「まだ何も判定していない」状態が別の見た目になっていた。
        let lung = PlanQualityViewModel()
        lung.selectedProtocol = .builtIn(.rtog0813)
        #expect(!lung.hasAnyJudgement, "入力が無い肺 SBRT では判定が 1 つも出ていない")

        let cranial = PlanQualityViewModel()
        cranial.selectedProtocol = .builtIn(.cranialSRS)
        #expect(!cranial.hasAnyJudgement,
                "入力が無い頭部定位照射も同じ扱いになる（以前はここだけ通常の背景だった）")
    }

    @Test("hasAnyJudgement: 頭部定位照射で MDPD が判定できると true になる")
    func hasAnyJudgementTrueWhenCranialJudges() {
        let vm = makeCranialVM()
        #expect(vm.mdpdDeviation != nil || vm.pitvDeviation != nil,
                "前提: この入力で判定が出ること")
        #expect(vm.hasAnyJudgement)
    }

    @Test("hasAnyJudgement: 判定が止まっている間は false")
    func hasAnyJudgementFalseWhenBlocked() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .builtIn(.rtog0813)
        vm.tvText = ""
        #expect(vm.judgementBlockedReason != nil, "前提: 判定が止まっていること")
        #expect(!vm.hasAnyJudgement)
    }

    @Test("isLungSBRTSelected: 未選択（.none）のときは false")
    func isLungSBRTSelectedFalseForNone() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(!vm.isLungSBRTSelected)
    }

    // MARK: - showsProtocolBackgroundNotes（判定パネルの「この判定基準について」折りたたみの表示条件）

    @Test("showsProtocolBackgroundNotes: 頭部定位照射選択時は true")
    func showsProtocolBackgroundNotesTrueForCranial() {
        let vm = makeCranialVM()
        #expect(vm.showsProtocolBackgroundNotes)
    }

    @Test("showsProtocolBackgroundNotes: 肺 SBRT（RTOG 0915 / 0813）選択時は true")
    func showsProtocolBackgroundNotesTrueForLungSBRT() {
        let vm915 = makeBaselineVM()
        #expect(vm915.showsProtocolBackgroundNotes)

        let vm813 = makeBaselineVM()
        vm813.selectedProtocol = .builtIn(.rtog0813)
        #expect(vm813.showsProtocolBackgroundNotes)
    }

    @Test("showsProtocolBackgroundNotes: 自施設の基準（.custom）選択時は false（背景注記を持たない）")
    func showsProtocolBackgroundNotesFalseForCustom() {
        let vm = makeBaselineVM()
        select(vm, customProtocol())
        #expect(!vm.showsProtocolBackgroundNotes)
    }

    @Test("showsProtocolBackgroundNotes: 未選択（.none）のときは false")
    func showsProtocolBackgroundNotesFalseForNone() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .none
        #expect(!vm.showsProtocolBackgroundNotes)
    }

    @Test(".builtIn(.rtog0915) / .builtIn(.rtog0813) の判定結果は頭部定位照射の追加後も 1 つも変わらない（境界値を含む）")
    func rtogJudgementUnaffectedByAddingCranialProtocol() {
        // R100%（体積によらず一定・1.2/1.5）の境界
        let vm915 = makeBaselineVM() // .builtIn(.rtog0915)
        #expect(vm915.r100Deviation == .perProtocol)
        vm915.pivText = "26.4" // ciRTOG = 26.4/22.0 = 1.2 ちょうど
        #expect(abs(vm915.ciRTOG! - 1.2) < 0.0001)
        #expect(vm915.r100Deviation == .minor, "R100% = 1.2 ちょうどは（従来どおり）minor のはず")

        // RTOG 0813（5 分割・50〜60 Gy）の境界も変わっていないこと
        let vm813 = makeBaselineVM()
        vm813.selectedProtocol = .builtIn(.rtog0813)
        vm813.fractionsText = "5"
        vm813.rxText = "60.0"
        #expect(vm813.judgementBlockedReason == nil, "0813 の 60 Gy/5 Fr（範囲の上限）が弾かれている")
        vm813.rxText = "65.0" // 13.0 Gy/回。StudiedSchedule.tolerance（0.05 Gy/回）を明確に超える
        #expect(vm813.judgementBlockedReason != nil, "0813 の範囲外（65.0 Gy/5 Fr）が通ってしまっている")
    }
}
