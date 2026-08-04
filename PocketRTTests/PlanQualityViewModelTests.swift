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

    @Test("分割数が選択プロトコルの範囲外だと判定できない（RTOG 0915 は 1〜4 分割）")
    func fractionsOutsideProtocolRangeBlocksJudgement() {
        let vm = makeBaselineVM()
        vm.fractionsText = "5"
        #expect(vm.judgementBlockedReason != nil)
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
