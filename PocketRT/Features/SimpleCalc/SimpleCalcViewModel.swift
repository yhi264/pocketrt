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
    @ObservationIgnored private var appliedPreset: PresetSelection?

    /// 現在の入力がプリセットと一致しているか。
    ///
    /// 表示文字列は `%.2f` で丸めて作るため、丸める前の値と完全一致で
    /// 比較すると、小数第 3 位以降を持つプリセットが適用直後から
    /// 自己不一致になる。丸め誤差（最大 0.005）を吸収できる許容差で比較する。
    private var matchesAppliedPreset: Bool {
        guard let p = appliedPreset,
              let d = Double(totalDoseText),
              abs(d - p.totalDose) < 0.01,
              Int(fractionsText) == p.fractions else { return false }
        return true
    }

    /// 現在の入力がプリセットと一致する場合のみ出典を返す。
    ///
    /// プリセット適用後にユーザーが数値を編集した場合、その結果はもはや
    /// プリセットの出典に帰属しない。誤った帰属を表示しないための判定。
    var activeCitations: [Citation] {
        guard matchesAppliedPreset else { return [] }
        return appliedPreset?.citations ?? []
    }

    /// 自施設プリセット由来のときだけ名前を返す。出典ではないので別の欄に出す。
    var activeInstitutionalName: String? {
        guard matchesAppliedPreset else { return nil }
        return appliedPreset?.institutionalName
    }

    func apply(_ selection: PresetSelection) {
        // 自施設プリセットは読み込み経路を持つため、範囲外の巨大な値
        // （例: 1e100）が totalDose に入りうる。DoseFormat は Int() 変換の
        // トラップを避け、その場合でも文字列を返す。
        totalDoseText = DoseFormat.doseString(selection.totalDose)
        fractionsText = "\(selection.fractions)"
        if let ab = selection.alphaBeta {
            alphaBetaText = DoseFormat.alphaBetaString(ab)
        }
        appliedPreset = selection
    }
}
