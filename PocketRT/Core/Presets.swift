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
        FractionationPreset(id: "conventional_head_neck", category: .conventional, site: "頭頸部根治",   totalDose: 70.0, fractions: 35, recommendedAlphaBeta: 10,  citations: [Citations.jastroHeadNeck]),
        FractionationPreset(id: "conventional_prostate", category: .conventional, site: "前立腺癌根治", totalDose: 78.0, fractions: 39, recommendedAlphaBeta: 1.5, citations: [Citations.jastroProstate]),
        FractionationPreset(id: "conventional_esophagus", category: .conventional, site: "食道癌根治",   totalDose: 60.0, fractions: 30, recommendedAlphaBeta: 10,  citations: [Citations.jcog0303, Citations.jcog0909]),
        FractionationPreset(id: "conventional_breast", category: .conventional, site: "乳癌温存術後", totalDose: 50.0, fractions: 25, recommendedAlphaBeta: 4,   citations: [Citations.jastroBreast]),
        FractionationPreset(id: "conventional_glioblastoma", category: .conventional, site: "Glioblastoma", totalDose: 60.0, fractions: 30, recommendedAlphaBeta: 10, citations: [Citations.stupp]),

        // 中等度寡分割
        FractionationPreset(id: "hypo_prostate_moderate", category: .hypofractionation, site: "前立腺癌中等度寡分割",   totalDose: 60.0,  fractions: 20, recommendedAlphaBeta: 1.5, citations: [Citations.chhip]),
        FractionationPreset(id: "hypo_breast_start_b", category: .hypofractionation, site: "乳癌寡分割 (START-B)",  totalDose: 40.05, fractions: 15, recommendedAlphaBeta: 4,   citations: [Citations.startB]),
        FractionationPreset(id: "hypo_breast_whelan", category: .hypofractionation, site: "乳癌寡分割 (Whelan)",   totalDose: 42.56, fractions: 16, recommendedAlphaBeta: 4,   citations: [Citations.whelan]),
        FractionationPreset(id: "hypo_breast_fast_forward", category: .hypofractionation, site: "乳癌超寡分割 (FAST-F)", totalDose: 26.0,  fractions: 5,  recommendedAlphaBeta: 4,   citations: [Citations.fastForward]),

        // SRT（頭蓋内）
        // 20 Gy と 24 Gy は出典が別である。RTOG 90-05 の線量段階に 20 Gy は無い
        // （Citations.jlgk0901 のコメント / data-sources.md §B3「訂正した誤り」4）。
        // どちらも腫瘍の大きさで条件が付くため、note に条件を明示する。
        FractionationPreset(id: "srt_brain_mets_srs_standard", category: .srt, site: "脳転移 SRS 単発・標準",   totalDose: 20.0, fractions: 1, recommendedAlphaBeta: 10, citations: [Citations.jlgk0901],
                            note: "JLGK0901 は腫瘍体積 4〜10 mL に辺縁線量 20 Gy を処方した（4 mL 未満は 22 Gy）"),
        FractionationPreset(id: "srt_brain_mets_srs_high", category: .srt, site: "脳転移 SRS 単発・高線量", totalDose: 24.0, fractions: 1, recommendedAlphaBeta: 10, citations: [Citations.rtog9005],
                            note: "RTOG 90-05 が最大径 20 mm 以下に定めた最大耐容線量。対象は再発・既照射例"),
        FractionationPreset(id: "srt_acoustic_neuroma", category: .srt, site: "聴神経腫瘍",             totalDose: 12.0, fractions: 1, recommendedAlphaBeta: 2,  citations: [Citations.jastroAcoustic]),

        // SBRT（体幹部）
        FractionationPreset(id: "sbrt_lung_peripheral", category: .sbrt, site: "早期肺癌 末梢", totalDose: 48.0,  fractions: 4, recommendedAlphaBeta: 10,  citations: [Citations.jcog0403],
                            note: "アイソセンタ処方"),
        FractionationPreset(id: "sbrt_lung_central", category: .sbrt, site: "早期肺癌 中心", totalDose: 60.0,  fractions: 8, recommendedAlphaBeta: 10,  citations: [Citations.jrosg10_1],
                            note: "アイソセンタ処方。JROSG10-1 の推奨線量"),

        // 緩和
        FractionationPreset(id: "palliative_bone_single", category: .palliative, site: "骨転移", totalDose:  8.0, fractions:  1, recommendedAlphaBeta: 10, citations: [Citations.bonePainTrial]),
        FractionationPreset(id: "palliative_bone_5fx", category: .palliative, site: "骨転移", totalDose: 20.0, fractions:  5, recommendedAlphaBeta: 10, citations: [Citations.boneMetsMeta]),
        FractionationPreset(id: "palliative_bone_10fx", category: .palliative, site: "骨転移",   totalDose: 30.0, fractions: 10, recommendedAlphaBeta: 10, citations: [Citations.boneMetsMeta]),
        FractionationPreset(id: "palliative_whole_brain", category: .palliative, site: "全脳照射",       totalDose: 30.0, fractions: 10, recommendedAlphaBeta: 10, citations: [Citations.jastroWholeBrain])
    ]

    static func byCategory(_ cat: PresetCategory) -> [FractionationPreset] {
        all.filter { $0.category == cat }
    }
}
