import Testing
@testable import PocketRT

@Suite("ConformityCriteria 判定表")
struct ConformityTableTests {

    @Test("表は 11 行、PTV 体積は昇順")
    func tableShape() {
        #expect(ConformityCriteria.table.count == 11)
        let volumes = ConformityCriteria.table.map(\.ptvVolume)
        #expect(volumes == volumes.sorted())
        #expect(volumes.first == 1.8)
        #expect(volumes.last == 163.0)
    }

    @Test("表の値は原典どおり（PTV 22.0 cc の行）")
    func exactRow22() {
        let l = ConformityCriteria.limits(ptvVolume: 22.0)
        #expect(l != nil)
        #expect(abs(l!.r50None - 4.5) < 0.0001)
        #expect(abs(l!.r50Minor - 5.5) < 0.0001)
        #expect(abs(l!.d2cmNone - 54.0) < 0.0001)
        #expect(abs(l!.d2cmMinor - 63.0) < 0.0001)
    }

    @Test("表の値は原典どおり（PTV 1.8 cc の行 = 下限）")
    func exactRowMin() {
        let l = ConformityCriteria.limits(ptvVolume: 1.8)
        #expect(l != nil)
        #expect(abs(l!.r50None - 5.9) < 0.0001)
        #expect(abs(l!.r50Minor - 7.5) < 0.0001)
        #expect(abs(l!.d2cmNone - 50.0) < 0.0001)
        #expect(abs(l!.d2cmMinor - 57.0) < 0.0001)
    }

    @Test("原典の誤植 >91.0 / >94.0 は < として転記されている")
    func typosCorrected() {
        let l126 = ConformityCriteria.limits(ptvVolume: 126.0)
        let l163 = ConformityCriteria.limits(ptvVolume: 163.0)
        #expect(abs(l126!.d2cmMinor - 91.0) < 0.0001)
        #expect(abs(l163!.d2cmMinor - 94.0) < 0.0001)
        // Minor は None より大きいこと（> と読むと逆転する）
        #expect(l126!.d2cmMinor > l126!.d2cmNone)
        #expect(l163!.d2cmMinor > l163!.d2cmNone)
    }

    @Test("表にない体積は線形補間する（原典 Note 1）— PTV 28.0 cc は 22.0 と 34.0 の中点")
    func linearInterpolation() {
        let l = ConformityCriteria.limits(ptvVolume: 28.0)
        #expect(l != nil)
        // r50None: 4.5 + 0.5*(4.3-4.5) = 4.4
        #expect(abs(l!.r50None - 4.4) < 0.0001)
        // r50Minor: 5.5 + 0.5*(5.3-5.5) = 5.4
        #expect(abs(l!.r50Minor - 5.4) < 0.0001)
        // d2cmNone: 54.0 + 0.5*(58.0-54.0) = 56.0
        #expect(abs(l!.d2cmNone - 56.0) < 0.0001)
        // d2cmMinor: 63.0 + 0.5*(68.0-63.0) = 65.5
        #expect(abs(l!.d2cmMinor - 65.5) < 0.0001)
    }

    @Test("表の範囲外は nil を返す（外挿しない）")
    func outOfRangeReturnsNil() {
        #expect(ConformityCriteria.limits(ptvVolume: 1.0) == nil)
        #expect(ConformityCriteria.limits(ptvVolume: 0) == nil)
        #expect(ConformityCriteria.limits(ptvVolume: 200.0) == nil)
        #expect(ConformityCriteria.limits(ptvVolume: 163.1) == nil)
    }

    @Test("R100% と V20 は体積によらず一定")
    func volumeIndependentLimits() {
        #expect(abs(ConformityCriteria.r100None - 1.2) < 0.0001)
        #expect(abs(ConformityCriteria.r100Minor - 1.5) < 0.0001)
        #expect(abs(ConformityCriteria.v20None - 10.0) < 0.0001)
        #expect(abs(ConformityCriteria.v20Minor - 15.0) < 0.0001)
    }
}

@Suite("ConformityCriteria 逸脱判定")
struct DeviationJudgementTests {

    @Test("none 未満は per protocol")
    func perProtocol() {
        #expect(ConformityCriteria.judge(value: 4.4, none: 4.5, minor: 5.5) == .perProtocol)
    }

    @Test("none 以上 minor 未満は minor deviation")
    func minorDeviation() {
        #expect(ConformityCriteria.judge(value: 5.0, none: 4.5, minor: 5.5) == .minor)
    }

    @Test("minor 以上は major deviation（原典 Note 2）")
    func majorDeviation() {
        #expect(ConformityCriteria.judge(value: 6.0, none: 4.5, minor: 5.5) == .major)
    }

    @Test("境界値は「未満」で判定する（表の表記が < のため）")
    func boundariesAreStrict() {
        // ちょうど none の値は per protocol ではなく minor
        #expect(ConformityCriteria.judge(value: 4.5, none: 4.5, minor: 5.5) == .minor)
        // ちょうど minor の値は minor ではなく major
        #expect(ConformityCriteria.judge(value: 5.5, none: 4.5, minor: 5.5) == .major)
    }

    // MARK: - 0813 / 0915 の判定結果が変わっていないことの固定（仕様 §2.3 改定の影響確認）

    @Test("R100%（体積によらず一定）の判定結果は改定前と変わらない。境界値を含む")
    func r100JudgementUnchanged() {
        #expect(ConformityCriteria.judge(value: 1.1, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 1.2, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor) == .minor)
        #expect(ConformityCriteria.judge(value: 1.5, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor) == .major)
    }

    @Test("V20（体積によらず一定）の判定結果は改定前と変わらない。境界値を含む")
    func v20JudgementUnchanged() {
        #expect(ConformityCriteria.judge(value: 9.9, none: ConformityCriteria.v20None, minor: ConformityCriteria.v20Minor) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 10.0, none: ConformityCriteria.v20None, minor: ConformityCriteria.v20Minor) == .minor)
        #expect(ConformityCriteria.judge(value: 15.0, none: ConformityCriteria.v20None, minor: ConformityCriteria.v20Minor) == .major)
    }

    @Test("R50% / D2cm（PTV 22.0 cc の行）の判定結果は改定前と変わらない。境界値を含む")
    func volumeDependentJudgementUnchanged() {
        let l = ConformityCriteria.limits(ptvVolume: 22.0)!
        // r50: None 4.5, Minor 5.5
        #expect(ConformityCriteria.judge(value: 4.4, none: l.r50None, minor: l.r50Minor) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 4.5, none: l.r50None, minor: l.r50Minor) == .minor)
        #expect(ConformityCriteria.judge(value: 5.5, none: l.r50None, minor: l.r50Minor) == .major)
        // d2cm: None 54.0, Minor 63.0
        #expect(ConformityCriteria.judge(value: 53.9, none: l.d2cmNone, minor: l.d2cmMinor) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 54.0, none: l.d2cmNone, minor: l.d2cmMinor) == .minor)
        #expect(ConformityCriteria.judge(value: 63.0, none: l.d2cmNone, minor: l.d2cmMinor) == .major)
    }
}

@Suite("ConformityCriteria 両側判定（仕様 §2.3）")
struct TwoSidedDeviationJudgementTests {

    // MARK: - 上限のみ・下限のみ・両方・どちらも無し

    @Test("上限のみ: 従来の片側判定と同じ結果になる（judge(value:none:minor:) の結果と一致）")
    func upperOnlyMatchesSingleSidedJudge() {
        for value in [4.0, 4.5, 5.0, 5.5, 6.0] {
            let expected = ConformityCriteria.judge(value: value, none: 4.5, minor: 5.5)
            let actual = ConformityCriteria.judge(value: value, upperNone: 4.5, upperMinor: 5.5)
            #expect(actual == expected, "value=\(value)")
        }
    }

    @Test("上限のみ・2段階（upperMinor 省略）: upperNone 未満なら基準内、それ以外は major")
    func upperOnlyTwoStage() {
        #expect(ConformityCriteria.judge(value: 4.4, upperNone: 4.5) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 4.5, upperNone: 4.5) == .major)
        #expect(ConformityCriteria.judge(value: 100, upperNone: 4.5) == .major)
    }

    @Test("下限のみ・3段階: lowerNone 以上なら基準内、下回るほど段階が悪化する")
    func lowerOnlyThreeStage() {
        // lowerNone: 1.0, lowerMinor: 0.9 のような下限判定（頭部定位照射 PITV を想定した形）。
        // 上限側と非対称に、lowerNone は含む（原典 Shaw 1993 が明示している境界のため）。
        #expect(ConformityCriteria.judge(value: 1.1, lowerNone: 1.0, lowerMinor: 0.9) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 1.0, lowerNone: 1.0, lowerMinor: 0.9) == .perProtocol, "lowerNone ちょうどは基準内（原典が明示している境界）")
        #expect(ConformityCriteria.judge(value: 0.95, lowerNone: 1.0, lowerMinor: 0.9) == .minor)
        #expect(ConformityCriteria.judge(value: 0.9, lowerNone: 1.0, lowerMinor: 0.9) == .major, "lowerMinor ちょうどは major（原典が定めておらず安全側に倒す）")
        #expect(ConformityCriteria.judge(value: 0.5, lowerNone: 1.0, lowerMinor: 0.9) == .major)
    }

    @Test("下限のみ・2段階（lowerMinor 省略）: lowerNone 以上なら基準内、それ以外は major")
    func lowerOnlyTwoStage() {
        #expect(ConformityCriteria.judge(value: 1.1, lowerNone: 1.0) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 1.0, lowerNone: 1.0) == .perProtocol, "lowerNone ちょうどは基準内")
        #expect(ConformityCriteria.judge(value: 0.999, lowerNone: 1.0) == .major)
        #expect(ConformityCriteria.judge(value: 0, lowerNone: 1.0) == .major)
    }

    @Test("両方: 範囲外（下限未満・上限以上）が逸脱。範囲内は基準内")
    func bothSides() {
        // 頭部定位照射 PITV を想定した形: upperNone 2.0 / upperMinor 2.5 / lowerNone 1.0 / lowerMinor 0.9
        #expect(ConformityCriteria.judge(value: 1.5, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .perProtocol, "範囲の中央")
        #expect(ConformityCriteria.judge(value: 1.0, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .perProtocol, "下限境界ちょうどは基準内（原典が明示）")
        #expect(ConformityCriteria.judge(value: 0.9, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .major, "下限の minor 境界ちょうどは major（原典が定めていない境界は安全側）")
        #expect(ConformityCriteria.judge(value: 2.0, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .minor, "上限境界ちょうどは悪い側（変更なし）")
        #expect(ConformityCriteria.judge(value: 2.5, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .major, "上限の minor 境界ちょうどは major（変更なし）")
        #expect(ConformityCriteria.judge(value: 0.1, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .major, "下限を大きく下回る")
        #expect(ConformityCriteria.judge(value: 10.0, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9) == .major, "上限を大きく上回る")
    }

    @Test("どちらも無し: 判定できないので nil を返す（0 や基準内にしない）")
    func neitherSideReturnsNil() {
        #expect(ConformityCriteria.judge(value: 1.0) == nil)
        #expect(ConformityCriteria.judge(value: 0) == nil)
        #expect(ConformityCriteria.judge(value: -100) == nil)
    }

    // MARK: - Shaw 1993 PITV の実値での境界固定（D4 で使う値。仕様 §2.3 / data-sources.md §B6）

    @Test("Shaw 1993 PITV の実値（lowerNone 1.0, lowerMinor 0.9, upperNone 2.0, upperMinor 2.5）で境界を固定する")
    func shaw1993PITVBoundaries() {
        let judge = { (value: Double) in
            ConformityCriteria.judge(value: value, upperNone: 2.0, upperMinor: 2.5, lowerNone: 1.0, lowerMinor: 0.9)
        }
        // 原典: "between 1.0 and 2.0" で per protocol
        #expect(judge(1.0) == .perProtocol, "下限 1.0 ちょうど（原典が明示: between 1.0 and 2.0）")
        #expect(judge(1.5) == .perProtocol)
        // 原典: "less than 1.0 but greater than 0.9" が minor
        #expect(judge(0.99) == .minor, "1.0 未満は minor（原典に明示）")
        #expect(judge(0.91) == .minor)
        // 原典が値を定めていない下限側の境界（0.9 ちょうど）は安全側で major
        #expect(judge(0.9) == .major)
        #expect(judge(0.5) == .major)
        // 上限側は既存の judge(value:none:minor:) の境界規約のまま（変更していない）
        #expect(judge(2.0) == .minor, "上限 2.0 ちょうどは minor（既存の判定表と同じ境界規約）")
        #expect(judge(2.4) == .minor)
        #expect(judge(2.5) == .major, "上限 2.5 ちょうどは major")
        #expect(judge(3.0) == .major)
    }

    // MARK: - upperNoneIsInclusive（仕様 §2.3「境界の包含関係の一覧」。MDPD = 2.0 の取り違えを固定）

    @Test("upperNoneIsInclusive の既定は false（含まない）。RTOG 0813 / 0915 の判定を動かさないための固定")
    func upperNoneIsInclusiveDefaultsToFalse() {
        // 引数を省略した呼び出しが、明示的に false を渡した場合と一致すること。
        // 将来誰かが既定を true に反転させたら、この境界（none ちょうど）で
        // 検出できる（R100% の許容値 1.2 を想定した値）。
        let omitted = ConformityCriteria.judge(value: 1.2, upperNone: 1.2, upperMinor: 1.5)
        let explicitFalse = ConformityCriteria.judge(value: 1.2, upperNone: 1.2, upperMinor: 1.5, upperNoneIsInclusive: false)
        #expect(omitted == explicitFalse)
        #expect(omitted == .minor, "既定（含まない）では none ちょうどは per protocol ではなく minor のはず")
    }

    @Test("upperNoneIsInclusive: true では none ちょうどが per protocol になる（3 段階）")
    func upperNoneIsInclusiveTrueThreeStage() {
        #expect(ConformityCriteria.judge(value: 1.9, upperNone: 2.0, upperMinor: 2.5, upperNoneIsInclusive: true) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 2.0, upperNone: 2.0, upperMinor: 2.5, upperNoneIsInclusive: true) == .perProtocol,
                "upperNoneIsInclusive: true では upperNone ちょうどが per protocol")
        #expect(ConformityCriteria.judge(value: 2.000001, upperNone: 2.0, upperMinor: 2.5, upperNoneIsInclusive: true) == .minor)
        #expect(ConformityCriteria.judge(value: 2.5, upperNone: 2.0, upperMinor: 2.5, upperNoneIsInclusive: true) == .major)
    }

    @Test("upperNoneIsInclusive: true・upperMinor 省略（2 段階）でも none ちょうどが per protocol になる")
    func upperNoneIsInclusiveTrueTwoStage() {
        #expect(ConformityCriteria.judge(value: 2.0, upperNone: 2.0, upperNoneIsInclusive: true) == .perProtocol)
        #expect(ConformityCriteria.judge(value: 2.000001, upperNone: 2.0, upperNoneIsInclusive: true) == .major)
    }

    // MARK: - Shaw 1993 MDPD の実値での境界固定（D4 で使う値。仕様 §2.1 / §2.3 / data-sources.md §B6）

    @Test("MDPD（mdpdUpperNone 2.0, mdpdUpperMinor 2.5, 上限含む）で境界を固定する")
    func shaw1993MDPDBoundaries() {
        let judge = { (value: Double) in
            ConformityCriteria.judge(value: value,
                                      upperNone: ConformityCriteria.mdpdUpperNone,
                                      upperMinor: ConformityCriteria.mdpdUpperMinor,
                                      upperNoneIsInclusive: true)
        }
        // 原典: "less than or equal to 2.0" が per protocol（2.0 ちょうどを含む）
        #expect(judge(1.5) == .perProtocol)
        #expect(judge(2.0) == .perProtocol, "原典が明示的に含める境界（less than or equal to 2.0）")
        // 原典: "greater than 2 but less than 2.5" が minor
        #expect(judge(2.01) == .minor)
        #expect(judge(2.4) == .minor)
        // 原典が定めていない境界（ちょうど 2.5）は安全側で major
        #expect(judge(2.5) == .major)
        #expect(judge(3.0) == .major)
    }

    @Test("MDPD の判定は upperNoneIsInclusive を渡し忘れると 2.0 ちょうどを誤判定する（回帰確認）")
    func mdpdBoundaryRegressionIfInclusiveFlagOmitted() {
        // upperNoneIsInclusive を渡し忘れた場合の挙動を明示的に確認する。
        // mdpdDeviation の実装がこの引数を渡し続けていることの裏付け
        // （渡し忘れは実装時に一度実際に起きた）。
        let withoutFlag = ConformityCriteria.judge(
            value: 2.0, upperNone: ConformityCriteria.mdpdUpperNone, upperMinor: ConformityCriteria.mdpdUpperMinor)
        #expect(withoutFlag == .minor, "引数を渡さないと 2.0 ちょうどが minor になってしまう（だから mdpdDeviation は必ず upperNoneIsInclusive: true を渡す）")
    }

    @Test("Shaw 1993 PITV の名前付き定数（pitvLowerNone 等）でも境界が変わっていないことを固定する")
    func shaw1993PITVBoundariesViaNamedConstants() {
        // shaw1993PITVBoundaries は生の数値で固定している。ここでは
        // ConformityCriteria.pitv* の名前付き定数を経由しても同じ結果になることを
        // 確かめる（PlanQualityViewModel.pitvDeviation が実際に使う経路）。
        let judge = { (value: Double) in
            ConformityCriteria.judge(value: value,
                                      upperNone: ConformityCriteria.pitvUpperNone, upperMinor: ConformityCriteria.pitvUpperMinor,
                                      lowerNone: ConformityCriteria.pitvLowerNone, lowerMinor: ConformityCriteria.pitvLowerMinor)
        }
        #expect(judge(1.0) == .perProtocol)
        #expect(judge(1.5) == .perProtocol)
        #expect(judge(0.99) == .minor)
        #expect(judge(0.9) == .major)
        #expect(judge(2.0) == .minor)
        #expect(judge(2.5) == .major)
    }

    @Test("RTOG 0813 / 0915 は upperNoneIsInclusive を渡さなくても境界が変わらない（既定 false の確認）")
    func rtogBoundariesUnaffectedByInclusiveParameter() {
        // R100%（1.2 / 1.5）を新しい両側 judge 経由で呼んでも、既定のままなら
        // 従来の片側 judge(value:none:minor:) と一致すること。
        for value in [1.1, 1.2, 1.4, 1.5, 1.6] {
            let legacy = ConformityCriteria.judge(value: value, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor)
            let viaTwoSided = ConformityCriteria.judge(value: value, upperNone: ConformityCriteria.r100None, upperMinor: ConformityCriteria.r100Minor)
            #expect(legacy == viaTwoSided, "value=\(value)")
        }
    }

    // MARK: - 段階名の出典切り替え（仕様 §3.1）

    @Test("段階名が出典で切り替わる")
    func displayNameDiffersBySource() {
        #expect(DeviationLevel.perProtocol.displayName != DeviationLevel.perProtocol.customDisplayName)
        #expect(DeviationLevel.minor.displayName != DeviationLevel.minor.customDisplayName)
        #expect(DeviationLevel.major.displayName != DeviationLevel.major.customDisplayName)

        #expect(DeviationLevel.perProtocol.customDisplayName == "基準内")
        #expect(DeviationLevel.minor.customDisplayName == "基準をやや超える")
        #expect(DeviationLevel.major.customDisplayName == "基準を超える")
    }

    @Test("公表プロトコル側の段階名が変わっていない")
    func publishedProtocolDisplayNameUnchanged() {
        #expect(DeviationLevel.perProtocol.displayName == "Per protocol")
        #expect(DeviationLevel.minor.displayName == "Minor deviation")
        #expect(DeviationLevel.major.displayName == "Major deviation")
    }
}
