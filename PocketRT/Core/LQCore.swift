import Foundation

/// Linear-Quadratic モデルに基づく純粋関数群
enum LQCore {

    /// BED = n · d · (1 + d / (α/β))、d = D / n
    static func bed(totalDose D: Double, fractions n: Int, alphaBeta: Double) -> Double {
        guard n > 0, alphaBeta > 0 else { return 0 }
        let d = D / Double(n)
        return D * (1.0 + d / alphaBeta)
    }

    /// EQD2 = BED / (1 + 2 / (α/β))
    static func eqd2(bed BED: Double, alphaBeta: Double) -> Double {
        guard alphaBeta > 0 else { return 0 }
        return BED / (1.0 + 2.0 / alphaBeta)
    }

    /// 多コースの BED 合算
    static func cumulativeBED(courses: [Course]) -> Double {
        courses.reduce(0.0) { sum, c in
            sum + bed(totalDose: c.totalDose, fractions: c.fractions, alphaBeta: c.alphaBeta)
        }
    }

    /// 多コースの EQD2 合算（各コースの BED → EQD2 を加算）
    static func cumulativeEQD2(courses: [Course]) -> Double {
        courses.reduce(0.0) { sum, c in
            let b = bed(totalDose: c.totalDose, fractions: c.fractions, alphaBeta: c.alphaBeta)
            return sum + eqd2(bed: b, alphaBeta: c.alphaBeta)
        }
    }

    /// OAR 制約換算
    /// sourceDose/sourceFractions/alphaBeta から BED を計算し、target に応じて変換
    static func convertConstraint(
        sourceDose: Double, sourceFractions: Int, alphaBeta: Double,
        target: ConversionTarget
    ) -> ConversionResult {
        let sourceBED = bed(totalDose: sourceDose, fractions: sourceFractions, alphaBeta: alphaBeta)

        switch target {
        case .fractions(let n_b):
            // d_b·(1 + d_b/(α/β)) · n_b = BED  → d_b について二次方程式を解く
            // d_b² + (α/β)·d_b - (α/β)·BED/n_b = 0
            // d_b = (α/β)/2 · [-1 + √(1 + 4·BED/(n_b·(α/β)))]
            guard n_b > 0, alphaBeta > 0 else {
                return ConversionResult(totalDose: 0, dosePerFraction: 0, fractions: n_b, bed: sourceBED, eqd2: 0)
            }
            let discriminant = 1.0 + 4.0 * sourceBED / (Double(n_b) * alphaBeta)
            let d_b = (alphaBeta / 2.0) * (-1.0 + discriminant.squareRoot())
            let D_b = Double(n_b) * d_b
            let newBED = bed(totalDose: D_b, fractions: n_b, alphaBeta: alphaBeta)
            return ConversionResult(
                totalDose: D_b,
                dosePerFraction: d_b,
                fractions: n_b,
                bed: newBED,
                eqd2: eqd2(bed: newBED, alphaBeta: alphaBeta)
            )

        case .dosePerFraction(let d_b):
            // d_b 固定で BED を満たす n_b を実数で算出、四捨五入
            guard d_b > 0, alphaBeta > 0 else {
                return ConversionResult(totalDose: 0, dosePerFraction: d_b, fractions: 0, bed: sourceBED, eqd2: 0)
            }
            let n_b_real = sourceBED / (d_b * (1.0 + d_b / alphaBeta))
            let n_b = max(1, Int(n_b_real.rounded()))
            let D_b = Double(n_b) * d_b
            let newBED = bed(totalDose: D_b, fractions: n_b, alphaBeta: alphaBeta)
            return ConversionResult(
                totalDose: D_b,
                dosePerFraction: d_b,
                fractions: n_b,
                bed: newBED,
                eqd2: eqd2(bed: newBED, alphaBeta: alphaBeta)
            )
        }
    }
}
