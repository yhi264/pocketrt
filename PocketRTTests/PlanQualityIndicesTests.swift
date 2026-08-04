import Testing
@testable import PocketRT

@Suite("PlanQualityIndices 指標計算")
struct PlanQualityIndicesTests {

    // TV=20.0, PIV=24.0, TV_PIV=18.0, V50%=90.0, Rx=48.0,
    // Dmax=60.0, D2%=52.0, D98%=45.0, D50%=48.0, D2cm=24.0 を共通の例とする

    @Test("CI(RTOG) = PIV/TV = 24.0/20.0 = 1.2")
    func ciRTOG() {
        let ci = PlanQualityIndices.conformityIndexRTOG(piv: 24.0, tv: 20.0)
        #expect(ci != nil)
        #expect(abs(ci! - 1.2) < 0.0001)
    }

    @Test("CI(Paddick) = TV_PIV²/(TV·PIV) = 324/480 = 0.675")
    func ciPaddick() {
        let ci = PlanQualityIndices.conformityIndexPaddick(tvPIV: 18.0, tv: 20.0, piv: 24.0)
        #expect(ci != nil)
        #expect(abs(ci! - 0.675) < 0.0001)
    }

    @Test("HI(RTOG) = Dmax/Rx = 60.0/48.0 = 1.25")
    func hiRTOG() {
        let hi = PlanQualityIndices.homogeneityIndexRTOG(maxDose: 60.0, prescriptionDose: 48.0)
        #expect(hi != nil)
        #expect(abs(hi! - 1.25) < 0.0001)
    }

    @Test("HI(ICRU-83) = (D2%−D98%)/D50% = (52−45)/48 = 0.145833")
    func hiICRU83() {
        let hi = PlanQualityIndices.homogeneityIndexICRU83(d2: 52.0, d98: 45.0, d50: 48.0)
        #expect(hi != nil)
        #expect(abs(hi! - 7.0 / 48.0) < 0.0001)
    }

    @Test("R50% = V50%/TV = 90.0/20.0 = 4.5")
    func r50() {
        let r = PlanQualityIndices.r50(v50: 90.0, tv: 20.0)
        #expect(r != nil)
        #expect(abs(r! - 4.5) < 0.0001)
    }

    @Test("GI(Paddick) = V50%/PIV = 90.0/24.0 = 3.75")
    func giPaddick() {
        let gi = PlanQualityIndices.gradientIndexPaddick(v50: 90.0, piv: 24.0)
        #expect(gi != nil)
        #expect(abs(gi! - 3.75) < 0.0001)
    }

    @Test("D2cm(%) = 24.0/48.0 × 100 = 50.0")
    func d2cmPercent() {
        let d = PlanQualityIndices.d2cmPercent(d2cmDose: 24.0, prescriptionDose: 48.0)
        #expect(d != nil)
        #expect(abs(d! - 50.0) < 0.0001)
    }

    @Test("0 や負の分母では nil を返す（0 として計算しない）")
    func guardsAgainstZeroDenominator() {
        #expect(PlanQualityIndices.conformityIndexRTOG(piv: 24.0, tv: 0) == nil)
        #expect(PlanQualityIndices.conformityIndexRTOG(piv: 24.0, tv: -1.0) == nil)
        #expect(PlanQualityIndices.homogeneityIndexICRU83(d2: 52.0, d98: 45.0, d50: 0) == nil)
        #expect(PlanQualityIndices.r50(v50: 90.0, tv: 0) == nil)
        #expect(PlanQualityIndices.d2cmPercent(d2cmDose: 24.0, prescriptionDose: 0) == nil)
    }

    @Test("非有限（inf）の入力・演算結果は指標として返さない")
    func guardsAgainstNonFiniteResult() {
        #expect(PlanQualityIndices.conformityIndexRTOG(piv: .infinity, tv: 20.0) == nil)
        #expect(PlanQualityIndices.r50(v50: .infinity, tv: 20.0) == nil)
        #expect(PlanQualityIndices.homogeneityIndexICRU83(d2: .infinity, d98: 45.0, d50: 48.0) == nil)
    }
}

@Suite("PlanQualityIndices 矛盾入力の検出")
struct PlanQualityValidationTests {

    @Test("整合した入力では問題を検出しない")
    func consistentInputHasNoIssues() {
        let issues = PlanQualityIndices.issues(
            tv: 20.0, piv: 24.0, tvPIV: 18.0, v50: 90.0,
            d2: 52.0, d98: 45.0, d50: 48.0)
        #expect(issues.isEmpty)
    }

    @Test("TV_PIV > TV は矛盾（PTV 内の部分体積が PTV を超えられない）")
    func tvPIVExceedsTV() {
        let issues = PlanQualityIndices.issues(
            tv: 20.0, piv: 24.0, tvPIV: 21.0, v50: 90.0,
            d2: nil, d98: nil, d50: nil)
        #expect(issues.contains(.tvPIVExceedsTV))
    }

    @Test("TV_PIV > PIV は矛盾（処方等線量体積の部分集合であるべき）")
    func tvPIVExceedsPIV() {
        let issues = PlanQualityIndices.issues(
            tv: 30.0, piv: 20.0, tvPIV: 25.0, v50: 90.0,
            d2: nil, d98: nil, d50: nil)
        #expect(issues.contains(.tvPIVExceedsPIV))
    }

    @Test("D98% > D2% は矛盾")
    func d98ExceedsD2() {
        let issues = PlanQualityIndices.issues(
            tv: nil, piv: nil, tvPIV: nil, v50: nil,
            d2: 45.0, d98: 52.0, d50: 48.0)
        #expect(issues.contains(.d98ExceedsD2))
    }

    @Test("D50% が D98%〜D2% の範囲外は矛盾")
    func d50OutOfRange() {
        let issues = PlanQualityIndices.issues(
            tv: nil, piv: nil, tvPIV: nil, v50: nil,
            d2: 52.0, d98: 45.0, d50: 60.0)
        #expect(issues.contains(.d50OutOfRange))
    }

    @Test("V50% < PIV は矛盾（50% 等線量体積は処方等線量体積を含む）")
    func v50LessThanPIV() {
        let issues = PlanQualityIndices.issues(
            tv: 20.0, piv: 24.0, tvPIV: 18.0, v50: 20.0,
            d2: nil, d98: nil, d50: nil)
        #expect(issues.contains(.v50LessThanPIV))
    }

    @Test("未入力（nil）の項目については矛盾を報告しない")
    func nilInputsProduceNoIssues() {
        let issues = PlanQualityIndices.issues(
            tv: nil, piv: nil, tvPIV: nil, v50: nil,
            d2: nil, d98: nil, d50: nil)
        #expect(issues.isEmpty)
    }
}
