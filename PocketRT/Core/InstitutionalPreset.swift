import Foundation

/// 利用者が登録した施設のプロトコル。
///
/// 内蔵プリセットとは別の型にしている。自施設プリセットは出典を持ちえず、
/// 型が違うことでそれが表れる。`name` と `note` は利用者の入力した
/// 実行時データなので `String` である（翻訳対象ではない）。
struct InstitutionalPreset: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var name: String
    var totalDose: Double
    var fractions: Int
    /// nil のときは、選択しても α/β を変更しない。
    /// プロトコルが α/β を定めていないのに値を入れさせると、
    /// 存在しない臨床的判断をアプリが作り出すことになる。
    var alphaBeta: Double?
    var note: String?
    var createdAt: Date

    /// 表示用: "60 Gy / 20 Fr"。内蔵プリセットと同じ書式。
    ///
    /// 自施設プリセットは取り込み経路（読み込み）を持つため、`totalDose` が
    /// 検証をすり抜けて範囲外の値（例: `1e100`）になりうる。`DoseFormat` は
    /// そのような値でもクラッシュせずに文字列を返す。
    var regimenLabel: String {
        DoseFormat.regimenLabel(totalDose: totalDose, fractions: fractions)
    }
}

/// 保存されるデータ全体
struct InstitutionalPresetData: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var presets: [InstitutionalPreset]
    /// 一覧から隠した内蔵プリセットの安定キー
    var hiddenBuiltInKeys: [String]

    static let empty = InstitutionalPresetData(
        schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
        presets: [], hiddenBuiltInKeys: [])
}
