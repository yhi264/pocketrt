import Foundation

/// 自施設の判定基準が扱う指標。
///
/// 公表プロトコル（RTOG 0813 / 0915）の判定表と同じ指標に固定する。
/// 表にない指標を追加させると、判定表との対応が取れなくなる。
///
/// v1 は R100% / R50% / D2cm の 3 指標のみ。**V20 を含まない。**
/// `ConformityCriteria` には V20 の許容値（`v20None`/`v20Minor`）が RTOG の
/// 表の転記として存在するが、アプリはこれを使って計算や判定を行っていない
/// （V20 の入力欄も判定プロパティも無い）。この状態で V20 の閾値を利用者に
/// 入力させると、値を入れたのに何も起きない「黙って効かない」状態になる。
/// V20 の入力欄と判定は将来の課題（バックログ）。
///
/// `Hashable` は `CustomProtocol.thresholds` の辞書キーとして使うために必要。
enum MetricKey: String, CaseIterable, Codable, Hashable, Sendable {
    case r100, r50, d2cm

    /// 表示用のラベル。放射線治療の標準的な略称であり翻訳しない
    /// （`ConformityCriteria` / `PlanQualityView` で使われている表記に合わせている）。
    var displayName: String {
        switch self {
        case .r100: "R100%"
        case .r50:  "R50%"
        case .d2cm: "D2cm"
        }
    }

    /// 表示用の単位。R100% / R50% は体積比、D2cm は処方線量に対する割合。
    var unitLabel: LocalizedStringResource {
        switch self {
        case .r100, .r50: "比"
        case .d2cm: "%"
        }
    }
}

/// 1 指標あたりの閾値。
///
/// `within` 未満なら「基準内」。`tolerated` が nil でなくその未満なら
/// 「基準をやや超える」、それ以外は「基準を超える」。`tolerated` が nil のときは
/// 2 段階（基準内 / 基準を超える）になる。
///
/// 判定の向きは常に「値が小さいほど良い」に固定する。選べるようにすると、
/// 「大きいほど良い」指標を誤って登録でき、判定が反転する。
struct MetricThreshold: Codable, Sendable, Equatable {
    var within: Double
    var tolerated: Double?
}

/// 利用者が登録した施設独自の判定基準。
///
/// 内蔵プロトコル（RTOG 0813 / 0915）とは別の型にしている。利用者定義の基準は
/// 出典を持ちえず、型が違うことでそれが表れる（D1 の `InstitutionalPreset` と同じ考え方）。
/// `name` と `note` は利用者が入力した実行時データなので `String` である
/// （翻訳対象ではない）。
struct CustomProtocol: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var name: String
    var note: String?
    var thresholds: [MetricKey: MetricThreshold]
    var createdAt: Date
}

// MARK: - 検証

/// 検証を通った入力
struct CustomProtocolDraft: Equatable, Sendable {
    var name: String
    var note: String?
    var thresholds: [MetricKey: MetricThreshold]
}

/// フォーム入力用（文字列のまま保持する）。指標ごとに「基準内」「許容」の 2 欄。
/// いずれも空欄を許す。
struct MetricThresholdInput: Equatable, Sendable {
    var within: String = ""
    var tolerated: String = ""
}

enum CustomProtocolValidationError: Error, Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    case noteTooLong
    /// 指標の閾値が範囲外。範囲は指標ごとに異なる（`CustomProtocolValidator.range(for:)`）。
    case thresholdOutOfRange(MetricKey)
    /// 「基準内」が空欄なのに「許容」だけが入力されている
    case toleratedWithoutWithin(MetricKey)
    /// `tolerated` が `within` より大きくない
    case toleratedNotGreaterThanWithin(MetricKey)
    /// 閾値が 1 つも入力されていない
    case noThresholds

    /// 編集画面は 3 指標 × 2 欄（基準内 / 許容）が並ぶため、メッセージは
    /// どの指標のことかを名指しする。範囲の値は `range(for:)` からその場で
    /// 導く（リテラルで書くと、範囲の定数を変えたときに文言が置き去りになる）。
    var message: LocalizedStringResource {
        switch self {
        case .nameEmpty:    "名前を入力してください"
        case .nameTooLong:  "名前は 40 文字までです"
        case .noteTooLong:  "メモは 100 文字までです"
        case .thresholdOutOfRange(let key):
            "\(key.displayName) の閾値は \(CustomProtocolValidator.rangeDescription(for: key)) で入力してください"
        case .toleratedWithoutWithin(let key):
            "\(key.displayName) の「基準をやや超える」だけでは判定に使えません。「基準内」も入力してください"
        case .toleratedNotGreaterThanWithin(let key):
            "\(key.displayName) の「基準をやや超える」の閾値は「基準内」より大きい値にしてください"
        case .noThresholds: "少なくとも 1 つの指標に閾値を入力してください"
        }
    }
}

/// `CustomProtocol` の入力検証。
///
/// `PresetValidator` と同じ構造にする。文字列版と数値版の両方を持ち、
/// 文字列版が数値に変換したあと数値版を呼ぶ。D1 では取り込み経路が検証を
/// 迂回して実行時クラッシュに至ったが、その原因は検証が二重定義されていた
/// ことだったので、最初から一本化する。
enum CustomProtocolValidator {

    /// R100% / R50% の閾値の範囲（体積比）
    private static let ratioRange = 0.1...20.0
    /// D2cm / V20 の閾値の範囲（処方線量比 %）
    private static let percentRange = 0.1...200.0

    static func range(for key: MetricKey) -> ClosedRange<Double> {
        switch key {
        case .r100, .r50: ratioRange
        case .d2cm: percentRange
        }
    }

    /// エラーメッセージに出す範囲の文字列表現。`range(for:)` から都度導く。
    /// 上下限が整数値なら小数点以下を付けない（"0.1〜20"）。
    ///
    /// 整形は `DoseFormat.plainString` に寄せる。独自の整形処理をここに
    /// 置かないこと（`Core/DoseFormatting.swift` 冒頭のコメントを参照）。
    static func rangeDescription(for key: MetricKey) -> String {
        let r = range(for: key)
        return "\(DoseFormat.plainString(r.lowerBound))〜\(DoseFormat.plainString(r.upperBound))"
    }

    /// 有限であることを必ず確認する。
    /// Double("inf") と Double("1e309") は +∞ を返し、範囲の比較を
    /// すり抜けうる。TPS からの貼り付けで到達する経路がある。
    private static func finite(_ s: String) -> Double? {
        guard let v = Double(s), v.isFinite else { return nil }
        return v
    }

    /// 文字列版（編集画面のフォーム入力から検証する）。
    static func validate(name: String, note: String, thresholds: [MetricKey: MetricThresholdInput])
        -> Result<CustomProtocolDraft, CustomProtocolValidationError> {

        var numeric: [MetricKey: MetricThreshold] = [:]
        for key in MetricKey.allCases {
            guard let input = thresholds[key] else { continue }
            let trimmedWithin = input.within.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTolerated = input.tolerated.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedWithin.isEmpty else {
                // 「基準内」が空欄のとき、「許容」だけが入っていても判定に使えない。
                guard trimmedTolerated.isEmpty else { return .failure(.toleratedWithoutWithin(key)) }
                continue // 両方空欄 = この指標は未設定
            }

            guard let within = finite(trimmedWithin) else { return .failure(.thresholdOutOfRange(key)) }

            var tolerated: Double?
            if !trimmedTolerated.isEmpty {
                guard let t = finite(trimmedTolerated) else { return .failure(.thresholdOutOfRange(key)) }
                tolerated = t
            }
            numeric[key] = MetricThreshold(within: within, tolerated: tolerated)
        }

        return validate(name: name, note: note, thresholds: numeric)
    }

    /// 数値版。フォーム入力の文字列版はこれのラッパーである。
    ///
    /// 取り込み（インポート）した JSON はデコードの時点で数値になっている。
    /// 数値を一度文字列に戻して文字列版に通すのは無駄であるだけでなく、
    /// 書式化を経由する分、値が変わる余地を作ってしまう。ここに数値版を
    /// 用意し、両方の入口が同じ範囲検証を共有するようにする。
    static func validate(name: String, note: String?, thresholds: [MetricKey: MetricThreshold])
        -> Result<CustomProtocolDraft, CustomProtocolValidationError> {

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.nameEmpty) }
        guard trimmedName.count <= 40 else { return .failure(.nameTooLong) }

        let trimmedNote = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 100 else { return .failure(.noteTooLong) }

        guard !thresholds.isEmpty else { return .failure(.noThresholds) }

        for key in MetricKey.allCases {
            guard let threshold = thresholds[key] else { continue }
            let validRange = range(for: key)

            guard threshold.within.isFinite, validRange.contains(threshold.within) else {
                return .failure(.thresholdOutOfRange(key))
            }

            if let tolerated = threshold.tolerated {
                guard tolerated.isFinite, validRange.contains(tolerated) else {
                    return .failure(.thresholdOutOfRange(key))
                }
                guard tolerated > threshold.within else {
                    return .failure(.toleratedNotGreaterThanWithin(key))
                }
            }
        }

        return .success(CustomProtocolDraft(
            name: trimmedName, note: trimmedNote.isEmpty ? nil : trimmedNote,
            thresholds: thresholds))
    }
}
