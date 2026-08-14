import Foundation

enum FractionationConversionMode: Hashable {
    case fractions
    case dosePerFraction
}

@Observable
final class FractionationConversionViewModel {
    var sourceDoseText: String = "50"
    var sourceFractionsText: String = "25"
    var alphaBetaText: String = "3"
    var mode: FractionationConversionMode = .fractions
    var targetFractionsText: String = "10"
    var targetDoseFxText: String = "3.0"

    var sourceDose: Double? { Double(sourceDoseText) }
    var sourceFractions: Int? { Int(sourceFractionsText) }
    var alphaBeta: Double? { Double(alphaBetaText) }
    var targetFractions: Int? { Int(targetFractionsText) }
    var targetDoseFx: Double? { Double(targetDoseFxText) }

    var sourceDoseError: String? {
        guard let v = sourceDose else { return sourceDoseText.isEmpty ? nil : String(localized: "数値を入力") }
        return (0.1...200).contains(v) ? nil : String(localized: "0.1〜200 Gy")
    }
    var sourceFractionsError: String? {
        guard let v = sourceFractions else { return sourceFractionsText.isEmpty ? nil : String(localized: "整数を入力") }
        return (1...99).contains(v) ? nil : String(localized: "1〜99 Fr")
    }
    var alphaBetaError: String? {
        guard let v = alphaBeta else { return alphaBetaText.isEmpty ? nil : String(localized: "数値を入力") }
        return (0.5...30).contains(v) ? nil : String(localized: "0.5〜30 Gy")
    }

    var targetError: String? {
        switch mode {
        case .fractions:
            guard let v = targetFractions else { return targetFractionsText.isEmpty ? nil : String(localized: "整数を入力") }
            return (1...99).contains(v) ? nil : String(localized: "1〜99 Fr")
        case .dosePerFraction:
            guard let v = targetDoseFx else { return targetDoseFxText.isEmpty ? nil : String(localized: "数値を入力") }
            return (0.1...30).contains(v) ? nil : String(localized: "0.1〜30 Gy")
        }
    }

    var isValid: Bool {
        sourceDoseError == nil && sourceFractionsError == nil
            && alphaBetaError == nil && targetError == nil
    }

    /// 元の線量分割だけで決まる入力が揃っているか。
    ///
    /// 換算先の入力とは独立に判定する。換算先を打っている途中で
    /// 元の BED が消えると、何と比べているのかが分からなくなる。
    private var sourceIsValid: Bool {
        sourceDoseError == nil && sourceFractionsError == nil && alphaBetaError == nil
    }

    /// 元の線量分割の BED。
    ///
    /// 換算は BED を保つように行われる。元の値を並べて出すことで、
    /// 換算後と一致しているかを利用者が目で確かめられる。
    /// 1 回線量を指定した場合は分割数を丸めるため厳密には一致しないので、
    /// そのずれもここで見える。
    var sourceBED: Double? {
        guard sourceIsValid,
              let D = sourceDose, let n = sourceFractions, let ab = alphaBeta else { return nil }
        return LQCore.bed(totalDose: D, fractions: n, alphaBeta: ab)
    }

    /// 元の線量分割の EQD2
    var sourceEQD2: Double? {
        guard let b = sourceBED, let ab = alphaBeta else { return nil }
        return LQCore.eqd2(bed: b, alphaBeta: ab)
    }

    var result: ConversionResult? {
        guard isValid,
              let D = sourceDose, let n = sourceFractions, let ab = alphaBeta else { return nil }
        let target: ConversionTarget = switch mode {
        case .fractions: .fractions(targetFractions ?? 0)
        case .dosePerFraction: .dosePerFraction(targetDoseFx ?? 0)
        }
        return LQCore.convertFractionation(
            sourceDose: D, sourceFractions: n, alphaBeta: ab, target: target
        )
    }
}
