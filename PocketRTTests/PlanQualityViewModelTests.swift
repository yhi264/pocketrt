import Testing
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
        vm.selectedProtocol = .rtog0915
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
        vm.selectedProtocol = .rtog0915
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
        vm.selectedProtocol = .rtog0915
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
        vm.selectedProtocol = .rtog0915
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
        vm.selectedProtocol = .rtog0813
        vm.fractionsText = "\(n)"
        #expect(vm.judgementBlockedReason != nil, "\(n) 分割が一致として通っている")
    }

    @Test("RTOG 0813 は 5 分割で 50〜60 Gy を一致とする",
          arguments: ["50.0", "55.0", "60.0"])
    func rtog0813AcceptsStudiedDoseRange(rx: String) {
        // 10〜12 Gy/回 × 5 分割
        let vm = makeBaselineVM()
        vm.selectedProtocol = .rtog0813
        vm.fractionsText = "5"
        vm.rxText = rx
        #expect(vm.judgementBlockedReason == nil, "\(rx) Gy / 5 Fr が弾かれている")
    }

    @Test("RTOG 0813 は 5 分割でも範囲外の線量を一致としない",
          arguments: ["40.0", "70.0"])
    func rtog0813RejectsDoseOutsideStudiedRange(rx: String) {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .rtog0813
        vm.fractionsText = "5"
        vm.rxText = rx
        #expect(vm.judgementBlockedReason != nil, "\(rx) Gy / 5 Fr が一致として通っている")
        #expect(vm.judgementBlockKind == .outsideProtocolScope)
    }

    @Test("線量が合わない理由は、検討された線量分割を示す")
    func doseMismatchReasonNamesStudiedSchedule() {
        let vm = makeBaselineVM()
        vm.selectedProtocol = .rtog0915
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
        vm.selectedProtocol = .rtog0915
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
}
