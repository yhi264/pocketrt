import Testing
@testable import PocketRT

// MARK: - BED

@Suite("LQCore.bed")
struct LQCoreBEDTests {

    @Test("60 Gy / 30 Fr / α/β=10 → BED=72.0")
    func conventional() {
        let bed = LQCore.bed(totalDose: 60.0, fractions: 30, alphaBeta: 10.0)
        #expect(abs(bed - 72.0) < 0.01)
    }

    @Test("78 Gy / 39 Fr / α/β=1.5 → BED≈182.0 (前立腺通常分割)")
    func prostateConventional() {
        let bed = LQCore.bed(totalDose: 78.0, fractions: 39, alphaBeta: 1.5)
        #expect(abs(bed - 182.0) < 0.01)
    }

    @Test("48 Gy / 4 Fr / α/β=10 → BED=105.6 (JCOG0403 SBRT)")
    func sbrtLung() {
        let bed = LQCore.bed(totalDose: 48.0, fractions: 4, alphaBeta: 10.0)
        #expect(abs(bed - 105.6) < 0.01)
    }

    @Test("Single 8 Gy / 1 Fr / α/β=10 → BED=14.4 (骨転移単回)")
    func bonePalliative() {
        let bed = LQCore.bed(totalDose: 8.0, fractions: 1, alphaBeta: 10.0)
        #expect(abs(bed - 14.4) < 0.01)
    }
}

// MARK: - EQD2

@Suite("LQCore.eqd2")
struct LQCoreEQD2Tests {

    @Test("BED=72 / α/β=10 → EQD2=60.0")
    func conventional() {
        let eqd2 = LQCore.eqd2(bed: 72.0, alphaBeta: 10.0)
        #expect(abs(eqd2 - 60.0) < 0.01)
    }

    @Test("BED=105.6 / α/β=10 → EQD2=88.0 (SBRT 等価)")
    func sbrt() {
        let eqd2 = LQCore.eqd2(bed: 105.6, alphaBeta: 10.0)
        #expect(abs(eqd2 - 88.0) < 0.01)
    }

    @Test("前立腺寡分割: 60Gy/20Fr α/β=1.5 → EQD2≈77.14")
    func prostateHypo() {
        let bed = LQCore.bed(totalDose: 60.0, fractions: 20, alphaBeta: 1.5)
        let eqd2 = LQCore.eqd2(bed: bed, alphaBeta: 1.5)
        #expect(abs(eqd2 - 77.14) < 0.05)
    }
}

// MARK: - Cumulative

@Suite("LQCore.cumulative")
struct LQCoreCumulativeTests {

    @Test("2コース合算: 60Gy/30Fr + 30Gy/10Fr (α/β=10) → ΣBED=111.0")
    func twoCoursesBED() {
        let courses = [
            Course(totalDose: 60.0, fractions: 30, alphaBeta: 10.0),
            Course(totalDose: 30.0, fractions: 10, alphaBeta: 10.0)
        ]
        let sum = LQCore.cumulativeBED(courses: courses)
        #expect(abs(sum - 111.0) < 0.01)
    }

    @Test("2コース合算 EQD2: 60Gy/30Fr + 30Gy/10Fr (α/β=10) → ΣEQD2=92.5")
    func twoCoursesEQD2() {
        let courses = [
            Course(totalDose: 60.0, fractions: 30, alphaBeta: 10.0),
            Course(totalDose: 30.0, fractions: 10, alphaBeta: 10.0)
        ]
        let sum = LQCore.cumulativeEQD2(courses: courses)
        #expect(abs(sum - 92.5) < 0.01)
    }

    @Test("3コース合算 BED: 50/25 + 30/10 + 20/5 (α/β=10) → ΣBED=127.0")
    func threeCoursesBED() {
        let courses = [
            Course(totalDose: 50.0, fractions: 25, alphaBeta: 10.0),
            Course(totalDose: 30.0, fractions: 10, alphaBeta: 10.0),
            Course(totalDose: 20.0, fractions: 5,  alphaBeta: 10.0)
        ]
        let sum = LQCore.cumulativeBED(courses: courses)
        #expect(abs(sum - 127.0) < 0.01)
    }

    @Test("空配列 → 0")
    func empty() {
        #expect(LQCore.cumulativeBED(courses: []) == 0.0)
        #expect(LQCore.cumulativeEQD2(courses: []) == 0.0)
    }
}

// MARK: - Convert: fractions mode

@Suite("LQCore.convertFractionation.fractions")
struct LQCoreConvertFractionsTests {

    @Test("50Gy/25Fr (α/β=3) → 10Fr 換算で D≈37.2 Gy")
    func standardToHypo() {
        let result = LQCore.convertFractionation(
            sourceDose: 50.0, sourceFractions: 25, alphaBeta: 3.0,
            target: .fractions(10)
        )
        // BED(50,25,3) = 50*(1+2/3) = 250/3 = 83.333
        // n_b=10: d_b = 1.5 * (-1 + √(1 + 4*83.333/30)) = 1.5*(-1+√12.111) = 1.5*(3.480-1) = 3.72
        // D_b = 37.2
        #expect(abs(result.totalDose - 37.2) < 0.1)
        #expect(abs(result.dosePerFraction - 3.72) < 0.02)
        #expect(result.fractions == 10)
    }

    @Test("28Gy/10Fr (α/β=3) → 3Fr 換算")
    func conversionHigherHypo() {
        let result = LQCore.convertFractionation(
            sourceDose: 28.0, sourceFractions: 10, alphaBeta: 3.0,
            target: .fractions(3)
        )
        // BED(28,10,3) = 28*(1+2.8/3) = 54.13
        // n_b=3: d_b = 1.5 * (-1 + √(1+72.18/9)) = 1.5*(-1+√9.020) = 1.5*(3.0033-1) = 3.005
        // 訂正: 4*54.13/(3*3) = 216.52/9 = 24.058, discriminant=25.058, √=5.006, d_b=1.5*(5.006-1)=6.009 → D=18.03
        // 上記の計画書例は誤算定。実際の式に基づき D≈18.0
        #expect(abs(result.totalDose - 18.03) < 0.1)
        #expect(result.fractions == 3)
    }
}

// MARK: - Convert: dosePerFraction mode

@Suite("LQCore.convertFractionation.dosePerFraction")
struct LQCoreConvertDoseTests {

    @Test("50Gy/25Fr (α/β=3) → 3Gy/Fr 指定で n=14 D=42.0")
    func standardToDoseFx() {
        let result = LQCore.convertFractionation(
            sourceDose: 50.0, sourceFractions: 25, alphaBeta: 3.0,
            target: .dosePerFraction(3.0)
        )
        // BED=83.33, d=3, n_real = 83.33 / (3*(1+3/3)) = 83.33/6 = 13.889 → 14
        #expect(result.fractions == 14)
        #expect(abs(result.dosePerFraction - 3.0) < 0.01)
        #expect(abs(result.totalDose - 42.0) < 0.01)
    }

    @Test("28Gy/10Fr (α/β=3) → 8Gy/Fr 指定で n=2 D=16.0")
    func sbrtToSingleFraction() {
        let result = LQCore.convertFractionation(
            sourceDose: 28.0, sourceFractions: 10, alphaBeta: 3.0,
            target: .dosePerFraction(8.0)
        )
        // BED=54.13, d=8, n_real = 54.13/(8*(1+8/3)) = 54.13/29.33 = 1.846 → 2
        #expect(result.fractions == 2)
        #expect(abs(result.totalDose - 16.0) < 0.01)
    }

    @Test("極端に小さい d_b（1e-300）でも n_b_real が Int に収まらずクラッシュせず、退化した結果を返す")
    func extremelySmallDoseFractionDoesNotCrash() {
        // n_b_real = BED / (d_b * (1 + d_b/alphaBeta)) は d_b が 0 に近いほど
        // 発散する。呼び出し元（ViewModel）は d_b を 0.1〜30 に制限しているが、
        // convertFractionation 自体はその検証を持たない純粋関数なので、
        // 範囲外の入力を直接渡してもトラップしないことを確かめる。
        let result = LQCore.convertFractionation(
            sourceDose: 200.0, sourceFractions: 1, alphaBeta: 0.5,
            target: .dosePerFraction(1e-300)
        )
        // 直前の guard（d_b > 0, alphaBeta > 0）と同じ退化した結果になる。
        #expect(result.fractions == 0)
        #expect(result.totalDose == 0)
        #expect(result.dosePerFraction == 1e-300)
    }

    @Test("d_b が非常に大きく分母が +Infinity に発散しても、Int(exactly:) は 0 として成功し n=1 に丸まる")
    func denominatorOverflowToInfinityYieldsSingleFraction() {
        // これは extremelySmallDoseFractionDoesNotCrash とは別の経路を確かめる
        // テストである。d_b が大きいと denom（d_b * (1 + d_b/alphaBeta)）自体が
        // Double の表現範囲を超えて +Infinity になり、n_b_real = sourceBED / Infinity
        // は「Int に収まらない大きな値」ではなく「厳密に 0.0」になる。
        // Int(exactly: 0.0) は失敗せず 0 を返すので、guard let n_b_rounded には
        // 入らず、直後の max(1, 0) で n=1 に丸められる。
        //
        // つまりこのテストは Int(exactly:) の失敗（トラップ回避）を検証しない
        // ——素の Int() に戻しても、この入力では 0 が返るだけで落ちない。
        // ここで確かめたいのは、denom が Infinity に発散する側の経路も
        // （guard に入る側の経路と同様に）決定的な値を返し、クラッシュしたり
        // NaN が紛れ込んだりしないこと。
        let result = LQCore.convertFractionation(
            sourceDose: 200.0, sourceFractions: 1, alphaBeta: 0.5,
            target: .dosePerFraction(1e300)
        )
        #expect(result.fractions == 1)
        #expect(result.totalDose == 1e300)
        #expect(result.dosePerFraction == 1e300)
        #expect(result.bed == .infinity, "BED も同じ発散で +Infinity になる（NaN にはならない）")
        #expect(result.eqd2 == .infinity)
    }
}

// MARK: - Boundary

@Suite("LQCore boundary")
struct LQCoreBoundaryTests {

    @Test("n=0 → BED=0 (ガード)")
    func zeroFractions() {
        #expect(LQCore.bed(totalDose: 60, fractions: 0, alphaBeta: 10) == 0)
    }

    @Test("α/β=0 → BED=0 (ガード)")
    func zeroAlphaBeta() {
        #expect(LQCore.bed(totalDose: 60, fractions: 30, alphaBeta: 0) == 0)
        #expect(LQCore.eqd2(bed: 72, alphaBeta: 0) == 0)
    }

    @Test("最大入力 200Gy/99Fr → 計算可能")
    func maxInput() {
        let bed = LQCore.bed(totalDose: 200, fractions: 99, alphaBeta: 10)
        // d=200/99≈2.02, BED = 200*(1+2.02/10) = 200*1.202 = 240.4
        #expect(bed > 200)
        #expect(bed < 300)
    }

    @Test("最小入力 0.1Gy/1Fr → 計算可能")
    func minInput() {
        let bed = LQCore.bed(totalDose: 0.1, fractions: 1, alphaBeta: 10)
        // d=0.1, BED = 0.1*(1+0.01) = 0.101
        #expect(abs(bed - 0.101) < 0.001)
    }
}
