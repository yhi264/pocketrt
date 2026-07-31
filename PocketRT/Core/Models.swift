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
enum PresetCategory: String, CaseIterable, Identifiable {
    case conventional      = "通常分割"
    case hypofractionation = "中等度寡分割"
    case srt               = "SRT（頭蓋内）"
    case sbrt              = "SBRT（体幹部）"
    case palliative        = "緩和"

    var id: String { rawValue }
}

/// 線量分割プリセット
struct FractionationPreset: Identifiable, Hashable {
    let id: UUID
    let category: PresetCategory
    let site: String           // "頭頸部根治"
    let totalDose: Double
    let fractions: Int
    let recommendedAlphaBeta: Double
    let source: String         // "JCOG0403"
    let note: String?

    init(
        id: UUID = UUID(),
        category: PresetCategory,
        site: String,
        totalDose: Double,
        fractions: Int,
        recommendedAlphaBeta: Double,
        source: String,
        note: String? = nil
    ) {
        self.id = id
        self.category = category
        self.site = site
        self.totalDose = totalDose
        self.fractions = fractions
        self.recommendedAlphaBeta = recommendedAlphaBeta
        self.source = source
        self.note = note
    }

    /// 表示用: "60 Gy / 30 Fr"
    var regimenLabel: String {
        let doseStr = totalDose == totalDose.rounded() ? "\(Int(totalDose))" : String(format: "%.2f", totalDose)
        return "\(doseStr) Gy / \(fractions) Fr"
    }
}
