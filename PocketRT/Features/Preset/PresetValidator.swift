import Foundation

/// 検証を通った入力
struct InstitutionalPresetDraft: Equatable, Sendable {
    var name: String
    var totalDose: Double
    var fractions: Int
    var alphaBeta: Double?
    var note: String?
}

enum PresetValidationError: Error, Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    case totalDoseOutOfRange
    case fractionsOutOfRange
    case alphaBetaOutOfRange
    case noteTooLong

    var message: LocalizedStringResource {
        switch self {
        case .nameEmpty:            "名前を入力してください"
        case .nameTooLong:          "名前は 40 文字までです"
        case .totalDoseOutOfRange:  "総線量は 0.1〜200 Gy で入力してください"
        case .fractionsOutOfRange:  "分割数は 1〜99 で入力してください"
        case .alphaBetaOutOfRange:  "α/β は 0.5〜30 Gy で入力してください"
        case .noteTooLong:          "メモは 100 文字までです"
        }
    }
}

enum PresetValidator {
    /// 有限であることを必ず確認する。
    /// Double("inf") と Double("1e309") は +∞ を返し、範囲の比較を
    /// すり抜けうる。TPS からの貼り付けで到達する経路がある。
    private static func finite(_ s: String) -> Double? {
        guard let v = Double(s), v.isFinite else { return nil }
        return v
    }

    static func validate(name: String, totalDose: String, fractions: String,
                         alphaBeta: String, note: String)
        -> Result<InstitutionalPresetDraft, PresetValidationError> {

        guard let dose = finite(totalDose) else { return .failure(.totalDoseOutOfRange) }
        guard let fx = Int(fractions) else { return .failure(.fractionsOutOfRange) }

        let trimmedAB = alphaBeta.trimmingCharacters(in: .whitespacesAndNewlines)
        var ab: Double?
        if !trimmedAB.isEmpty {
            guard let v = finite(trimmedAB) else { return .failure(.alphaBetaOutOfRange) }
            ab = v
        }

        return validate(name: name, totalDose: dose, fractions: fx, alphaBeta: ab, note: note)
    }

    /// 数値をそのまま検証する。フォーム入力の文字列版はこれのラッパーである。
    ///
    /// 取り込み（インポート）した JSON はデコードの時点で数値になっている。
    /// 数値を一度文字列に戻して文字列版に通すのは無駄であるだけでなく、
    /// 書式化を経由する分、値が変わる余地を作ってしまう。ここに数値版を
    /// 用意し、両方の入口が同じ範囲検証を共有するようにする。
    static func validate(name: String, totalDose: Double, fractions: Int,
                         alphaBeta: Double?, note: String?)
        -> Result<InstitutionalPresetDraft, PresetValidationError> {

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.nameEmpty) }
        guard trimmedName.count <= 40 else { return .failure(.nameTooLong) }

        guard totalDose.isFinite, totalDose >= 0.1, totalDose <= 200 else {
            return .failure(.totalDoseOutOfRange)
        }

        guard fractions >= 1, fractions <= 99 else {
            return .failure(.fractionsOutOfRange)
        }

        if let ab = alphaBeta {
            guard ab.isFinite, ab >= 0.5, ab <= 30 else {
                return .failure(.alphaBetaOutOfRange)
            }
        }

        let trimmedNote = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 100 else { return .failure(.noteTooLong) }

        return .success(InstitutionalPresetDraft(
            name: trimmedName, totalDose: totalDose, fractions: fractions,
            alphaBeta: alphaBeta, note: trimmedNote.isEmpty ? nil : trimmedNote))
    }
}
