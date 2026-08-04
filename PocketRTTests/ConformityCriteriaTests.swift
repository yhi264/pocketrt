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
}
