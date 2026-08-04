import Foundation

/// 1コース分の処方
struct Course: Hashable, Identifiable {
    let id: UUID
    var totalDose: Double      // Gy
    var fractions: Int
    var alphaBeta: Double      // Gy

    init(id: UUID = UUID(), totalDose: Double, fractions: Int, alphaBeta: Double) {
        self.id = id
        self.totalDose = totalDose
        self.fractions = fractions
        self.alphaBeta = alphaBeta
    }

    var dosePerFraction: Double {
        fractions > 0 ? totalDose / Double(fractions) : 0
    }
}

/// OAR制約換算の指定方式
enum ConversionTarget: Hashable {
    case fractions(Int)
    case dosePerFraction(Double)
}

/// OAR制約換算の結果
struct ConversionResult: Hashable {
    let totalDose: Double
    let dosePerFraction: Double
    let fractions: Int
    let bed: Double
    let eqd2: Double
}

/// α/β プリセット（早見表用）
struct AlphaBetaPreset: Identifiable, Hashable {
    let id: UUID
    let label: String           // "腫瘍（一般）"
    let value: Double           // 10.0
    let note: String?           // "デフォルト"

    init(id: UUID = UUID(), label: String, value: Double, note: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.note = note
    }
}

/// 線量分割プリセットのカテゴリ
///
/// rawValue は**言語非依存の安定キー**。表示名は `displayName` を使う。
/// rawValue を表示に使うと、ローカライズ時に id が言語設定で変わってしまう。
enum PresetCategory: String, CaseIterable, Identifiable, Sendable {
    case conventional
    case hypofractionation
    case srt
    case sbrt
    case palliative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conventional:      String(localized: "通常分割")
        case .hypofractionation: String(localized: "中等度寡分割")
        case .srt:               String(localized: "SRT（頭蓋内）")
        case .sbrt:               String(localized: "SBRT（体幹部）")
        case .palliative:        String(localized: "緩和")
        }
    }
}

/// 線量分割プリセット
struct FractionationPreset: Identifiable {
    let id: UUID
    let category: PresetCategory
    let site: String           // "頭頸部根治"
    let totalDose: Double
    let fractions: Int
    let recommendedAlphaBeta: Double
    let citations: [Citation]
    let note: String?

    init(
        id: UUID = UUID(),
        category: PresetCategory,
        site: String,
        totalDose: Double,
        fractions: Int,
        recommendedAlphaBeta: Double,
        citations: [Citation],
        note: String? = nil
    ) {
        self.id = id
        self.category = category
        self.site = site
        self.totalDose = totalDose
        self.fractions = fractions
        self.recommendedAlphaBeta = recommendedAlphaBeta
        self.citations = citations
        self.note = note
    }

    /// 表示用: "60 Gy / 30 Fr"
    var regimenLabel: String {
        let doseStr = totalDose == totalDose.rounded() ? "\(Int(totalDose))" : String(format: "%.2f", totalDose)
        return "\(doseStr) Gy / \(fractions) Fr"
    }
}

extension FractionationPreset: Hashable {
    static func == (lhs: FractionationPreset, rhs: FractionationPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// カレンダー表示用の 1 ヶ月ぶんのグリッド情報
struct MonthGrid: Identifiable, Hashable {
    /// 月初（その月の 1 日 0:00）
    let firstDay: Date
    /// 日曜始まりのグリッドで月初の前に置く空セル数（日曜=0 … 土曜=6）
    let leadingBlanks: Int
    /// その月の日数
    let dayCount: Int

    var id: Date { firstDay }
}
