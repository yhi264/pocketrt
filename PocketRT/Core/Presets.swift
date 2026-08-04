import Foundation

enum AlphaBetaPresets {
    static let all: [AlphaBetaPreset] = [
        AlphaBetaPreset(label: "腫瘍（一般）",         value: 10,  note: "デフォルト"),
        AlphaBetaPreset(label: "前立腺癌",             value: 1.5, note: "低 α/β 腫瘍"),
        AlphaBetaPreset(label: "乳癌",                value: 4,   note: "寡分割計算"),
        AlphaBetaPreset(label: "晩期反応組織（一般）", value: 3,   note: "OAR 既定"),
        AlphaBetaPreset(label: "脊髄",                value: 2),
        AlphaBetaPreset(label: "脳幹",                value: 2),
        AlphaBetaPreset(label: "皮膚（急性）",        value: 10),
        AlphaBetaPreset(label: "皮膚（晩期）",        value: 3)
    ]
}

enum FractionationPresets {
    static let all: [FractionationPreset] = [
        // 通常分割
        FractionationPreset(category: .conventional, site: "頭頸部根治",   totalDose: 70.0, fractions: 35, recommendedAlphaBeta: 10,  citations: [Citations.nccnHeadNeck]),
        FractionationPreset(category: .conventional, site: "前立腺癌根治", totalDose: 78.0, fractions: 39, recommendedAlphaBeta: 1.5, citations: [Citations.jastroProstate]),
        FractionationPreset(category: .conventional, site: "食道癌根治",   totalDose: 60.0, fractions: 30, recommendedAlphaBeta: 10,  citations: [Citations.jcog0303, Citations.jcog0909]),
        FractionationPreset(category: .conventional, site: "乳癌温存術後", totalDose: 50.0, fractions: 25, recommendedAlphaBeta: 4,   citations: [Citations.breastConventional]),
        FractionationPreset(category: .conventional, site: "Glioblastoma", totalDose: 60.0, fractions: 30, recommendedAlphaBeta: 10, citations: [Citations.stupp]),

        // 中等度寡分割
        FractionationPreset(category: .hypofractionation, site: "前立腺癌中等度寡分割",   totalDose: 60.0,  fractions: 20, recommendedAlphaBeta: 1.5, citations: [Citations.chhip]),
        FractionationPreset(category: .hypofractionation, site: "乳癌寡分割 (START-B)",  totalDose: 40.05, fractions: 15, recommendedAlphaBeta: 4,   citations: [Citations.startB]),
        FractionationPreset(category: .hypofractionation, site: "乳癌寡分割 (Whelan)",   totalDose: 42.56, fractions: 16, recommendedAlphaBeta: 4,   citations: [Citations.whelan]),
        FractionationPreset(category: .hypofractionation, site: "乳癌超寡分割 (FAST-F)", totalDose: 26.0,  fractions: 5,  recommendedAlphaBeta: 4,   citations: [Citations.fastForward]),

        // SRT（頭蓋内）
        FractionationPreset(category: .srt, site: "脳転移 SRS 単発・標準",   totalDose: 20.0, fractions: 1, recommendedAlphaBeta: 10, citations: [Citations.rtog9005]),
        FractionationPreset(category: .srt, site: "脳転移 SRS 単発・高線量", totalDose: 24.0, fractions: 1, recommendedAlphaBeta: 10, citations: [Citations.rtog9005]),
        FractionationPreset(category: .srt, site: "脳転移 分割SRT 27/3",     totalDose: 27.0, fractions: 3, recommendedAlphaBeta: 10, citations: [Citations.jlgk0901]),
        FractionationPreset(category: .srt, site: "脳転移 分割SRT 30/5",     totalDose: 30.0, fractions: 5, recommendedAlphaBeta: 10, citations: [Citations.conventionalRegimen]),
        FractionationPreset(category: .srt, site: "聴神経腫瘍",             totalDose: 12.0, fractions: 1, recommendedAlphaBeta: 2,  citations: [Citations.conventionalRegimen]),

        // SBRT（体幹部）
        FractionationPreset(category: .sbrt, site: "早期肺癌 末梢", totalDose: 48.0,  fractions: 4, recommendedAlphaBeta: 10,  citations: [Citations.jcog0403],
                            note: "アイソセンタ処方"),
        FractionationPreset(category: .sbrt, site: "早期肺癌 中心", totalDose: 60.0,  fractions: 8, recommendedAlphaBeta: 10,  citations: [Citations.jrosg10_1],
                            note: "アイソセンタ処方。JROSG10-1 の推奨線量"),
        FractionationPreset(category: .sbrt, site: "肝SBRT",       totalDose: 40.0,  fractions: 5, recommendedAlphaBeta: 10,  citations: [Citations.conventionalRegimen]),
        FractionationPreset(category: .sbrt, site: "前立腺SBRT",    totalDose: 36.25, fractions: 5, recommendedAlphaBeta: 1.5, citations: [Citations.paceB]),
        FractionationPreset(category: .sbrt, site: "脊椎転移SBRT", totalDose: 24.0,  fractions: 2, recommendedAlphaBeta: 10,  citations: [Citations.conventionalRegimen]),

        // 緩和
        FractionationPreset(category: .palliative, site: "骨転移 シングル", totalDose:  8.0, fractions:  1, recommendedAlphaBeta: 10, citations: [Citations.bonePainTrial]),
        FractionationPreset(category: .palliative, site: "骨転移 中等回数", totalDose: 20.0, fractions:  5, recommendedAlphaBeta: 10, citations: [Citations.boneMetsMeta]),
        FractionationPreset(category: .palliative, site: "骨転移 マルチ",   totalDose: 30.0, fractions: 10, recommendedAlphaBeta: 10, citations: [Citations.boneMetsMeta]),
        FractionationPreset(category: .palliative, site: "全脳照射",       totalDose: 30.0, fractions: 10, recommendedAlphaBeta: 10, citations: [Citations.conventionalRegimen])
    ]

    static func byCategory(_ cat: PresetCategory) -> [FractionationPreset] {
        all.filter { $0.category == cat }
    }
}
