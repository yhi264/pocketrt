import Foundation

@Observable
final class SimpleCalcViewModel {
    var totalDoseText: String = "60"
    var fractionsText: String = "30"
    var alphaBetaText: String = "10"

    var totalDose: Double? { Double(totalDoseText) }
    var fractions: Int? { Int(fractionsText) }
    var alphaBeta: Double? { Double(alphaBetaText) }

    var totalDoseError: String? {
        guard let v = totalDose else { return totalDoseText.isEmpty ? nil : String(localized: "数値を入力") }
        return (0.1...200).contains(v) ? nil : String(localized: "0.1〜200 Gy")
    }
    var fractionsError: String? {
        guard let v = fractions else { return fractionsText.isEmpty ? nil : String(localized: "整数を入力") }
        return (1...99).contains(v) ? nil : String(localized: "1〜99 Fr")
    }
    var alphaBetaError: String? {
        guard let v = alphaBeta else { return alphaBetaText.isEmpty ? nil : String(localized: "数値を入力") }
        return (0.5...30).contains(v) ? nil : String(localized: "0.5〜30 Gy")
    }

    var isValid: Bool {
        totalDoseError == nil && fractionsError == nil && alphaBetaError == nil
            && totalDose != nil && fractions != nil && alphaBeta != nil
    }

    var dosePerFraction: Double? {
        guard let D = totalDose, let n = fractions, n > 0 else { return nil }
        return D / Double(n)
    }
    var bed: Double? {
        guard isValid, let D = totalDose, let n = fractions, let ab = alphaBeta else { return nil }
        return LQCore.bed(totalDose: D, fractions: n, alphaBeta: ab)
    }
    var eqd2: Double? {
        guard let b = bed, let ab = alphaBeta else { return nil }
        return LQCore.eqd2(bed: b, alphaBeta: ab)
    }

    /// 直近に適用したプリセット。入力が編集されても保持し、
    /// 出典を出すかどうかは `activeCitations` が値の一致で判定する。
    @ObservationIgnored private var appliedPreset: FractionationPreset?

    /// 現在の入力がプリセットと一致する場合のみ出典を返す。
    ///
    /// プリセット適用後にユーザーが数値を編集した場合、その結果はもはや
    /// プリセットの出典に帰属しない。誤った帰属を表示しないための判定。
    var activeCitations: [Citation] {
        guard let p = appliedPreset,
              let d = totalDose, let n = fractions,
              abs(d - p.totalDose) < 0.001, n == p.fractions
        else { return [] }
        return p.citations
    }

    func apply(preset: FractionationPreset) {
        totalDoseText = preset.totalDose == preset.totalDose.rounded()
            ? "\(Int(preset.totalDose))"
            : String(format: "%.2f", preset.totalDose)
        fractionsText = "\(preset.fractions)"
        alphaBetaText = preset.recommendedAlphaBeta == preset.recommendedAlphaBeta.rounded()
            ? "\(Int(preset.recommendedAlphaBeta))"
            : String(format: "%.1f", preset.recommendedAlphaBeta)
        appliedPreset = preset
    }
}
