import Foundation

enum Citations {

    // MARK: - 一次文献が同定できているもの

    static let chhip = Citation(
        id: "chhip", shortLabel: "CHHiP",
        authors: "Dearnaley D, Syndikus I, Mossop H, et al.",
        title: "Conventional versus hypofractionated high-dose intensity-modulated radiotherapy for prostate cancer: 5-year outcomes of the randomised, non-inferiority, phase 3 CHHiP trial.",
        journal: "Lancet Oncol", year: 2016,
        pmid: "27339115", doi: "10.1016/S1470-2045(16)30102-4")

    static let startB = Citation(
        id: "start_b", shortLabel: "START-B",
        authors: "START Trialists' Group; Bentzen SM, Agrawal RK, et al.",
        title: "The UK Standardisation of Breast Radiotherapy (START) Trial B of radiotherapy hypofractionation for treatment of early breast cancer: a randomised trial.",
        journal: "Lancet", year: 2008,
        pmid: "18355913", doi: "10.1016/S0140-6736(08)60348-7")

    static let fastForward = Citation(
        id: "fast_forward", shortLabel: "FAST-Forward",
        authors: "Murray Brunt A, Haviland JS, Wheatley DA, et al.",
        title: "Hypofractionated breast radiotherapy for 1 week versus 3 weeks (FAST-Forward): 5-year efficacy and late normal tissue effects results from a multicentre, non-inferiority, randomised, phase 3 trial.",
        journal: "Lancet", year: 2020,
        pmid: "32580883", doi: "10.1016/S0140-6736(20)30932-6")

    static let whelan = Citation(
        id: "whelan_ocog", shortLabel: "Whelan 2010 (OCOG)",
        authors: "Whelan TJ, Pignol JP, Levine MN, et al.",
        title: "Long-term results of hypofractionated radiation therapy for breast cancer.",
        journal: "N Engl J Med", year: 2010,
        pmid: "20147717", doi: "10.1056/NEJMoa0906260")

    static let jcog0403 = Citation(
        id: "jcog0403", shortLabel: "JCOG0403",
        authors: "Nagata Y, Hiraoka M, Shibata T, et al.",
        title: "Prospective trial of stereotactic body radiation therapy for both operable and inoperable T1N0M0 non-small cell lung cancer: Japan Clinical Oncology Group study JCOG0403.",
        journal: "Int J Radiat Oncol Biol Phys", year: 2015,
        pmid: "26581137", doi: "10.1016/j.ijrobp.2015.07.2278")

    /// 中心型肺 SBRT 60 Gy/8 Fr の出典。
    /// 初版は JCOG0702 と誤記していた。JCOG0702 は末梢型 T2・4 分割であり別物。
    /// JASTRO 放射線治療計画ガイドライン 2020 胸部章も JROSG10-1 を中枢型の推奨線量として挙げている。
    static let jrosg10_1 = Citation(
        id: "jrosg10_1", shortLabel: "JROSG10-1",
        authors: "Kimura T, Nagata Y, Harada H, et al.",
        title: "Phase I study of stereotactic body radiation therapy for centrally located stage IA non-small cell lung cancer (JROSG10-1).",
        journal: "Int J Clin Oncol", year: 2017,
        pmid: "28466183", doi: "10.1007/s10147-017-1125-y")

    static let jcog0303 = Citation(
        id: "jcog0303", shortLabel: "JCOG0303",
        authors: "Shinoda M, Ando N, Kato K, et al.",
        title: "Randomized study of low-dose versus standard-dose chemoradiotherapy for unresectable esophageal squamous cell carcinoma (JCOG0303).",
        journal: "Cancer Sci", year: 2015,
        pmid: "25640628", doi: "10.1111/cas.12622")

    static let jcog0909 = Citation(
        id: "jcog0909", shortLabel: "JCOG0909",
        authors: "Ito Y, Takeuchi H, Ogawa G, et al.",
        title: "A single-arm confirmatory study of definitive chemoradiation therapy including salvage treatment for clinical stage II/III esophageal squamous cell carcinoma (JCOG0909).",
        journal: "Int J Radiat Oncol Biol Phys", year: 2022,
        pmid: "35932949", doi: "10.1016/j.ijrobp.2022.05.054")

    static let rtog9005 = Citation(
        id: "rtog_90_05", shortLabel: "RTOG 90-05",
        authors: "Shaw E, Scott C, Souhami L, et al.",
        title: "Single dose radiosurgical treatment of recurrent previously irradiated primary brain tumors and brain metastases: final report of RTOG protocol 90-05.",
        journal: "Int J Radiat Oncol Biol Phys", year: 2000,
        pmid: "10802351", doi: "10.1016/S0360-3016(99)00507-6")

    static let boneMetsMeta = Citation(
        id: "bone_mets_meta", shortLabel: "Rich/Chow 2018 メタ解析",
        authors: "Rich SE, Chow R, Raman S, et al.",
        title: "Update of the systematic review of palliative radiation therapy fractionation for bone metastases.",
        journal: "Radiother Oncol", year: 2018,
        pmid: "29397209", doi: "10.1016/j.radonc.2018.01.003")

    // MARK: - ガイドラインに明記されているもの（JASTRO 放射線治療計画ガイドライン 2020）

    static let jastroHeadNeck = Citation(
        id: "jastro_head_neck", shortLabel: "JASTRO 計画GL 2020 頭頸部",
        guidelineNote: "放射線治療計画ガイドライン 2020 年版 頭頸部「70 Gy/35 回/7 週の通常分割照射が標準分割照射法である」")

    static let jastroProstate = Citation(
        id: "jastro_prostate", shortLabel: "JASTRO 計画GL 2020 泌尿器",
        guidelineNote: "放射線治療計画ガイドライン 2020 年版 泌尿器「IMRT の場合には 74〜78 Gy が用いられることが多い」。分割数は同記載からは確認できない（1 回 2 Gy とすれば 39 回）")

    static let jastroBreast = Citation(
        id: "jastro_breast", shortLabel: "JASTRO 計画GL 2020 胸部",
        guidelineNote: "放射線治療計画ガイドライン 2020 年版 胸部「通常分割照射（50 Gy/25 回/35 日）」")

    static let jastroWholeBrain = Citation(
        id: "jastro_whole_brain", shortLabel: "JASTRO 計画GL 2020 緩和",
        guidelineNote: "放射線治療計画ガイドライン 2020 年版 緩和「全脳照射では、30 Gy/10 回/2 週が標準的である」")

    static let jastroAcoustic = Citation(
        id: "jastro_acoustic", shortLabel: "JASTRO 計画GL 2020 中枢神経",
        guidelineNote: "放射線治療計画ガイドライン 2020 年版 中枢神経「SRS：辺縁線量 12〜13 Gy で行われることが多く」")

    // MARK: - 一次文献が確定したもの（PubMed 照合済み・data-sources.md §B4.1）

    static let stupp = Citation(
        id: "stupp", shortLabel: "Stupp レジメン",
        authors: "Stupp R, Mason WP, van den Bent MJ, et al.",
        title: "Radiotherapy plus concomitant and adjuvant temozolomide for glioblastoma.",
        journal: "N Engl J Med", year: 2005,
        pmid: "15758009", doi: "10.1056/NEJMoa043330")

    static let bonePainTrial = Citation(
        id: "bone_pain_trial", shortLabel: "Bone Pain Trial",
        authors: "Bone Pain Trial Working Party.",
        title: "8 Gy single fraction radiotherapy for the treatment of metastatic skeletal pain: randomised comparison with a multifraction schedule over 12 months of patient follow-up.",
        journal: "Radiother Oncol", year: 1999,
        pmid: "10577696")

    // MARK: - 品質指標の逸脱判定に用いるプロトコル
    //
    // ここに置く 2 件は、線量分割プリセットの出典ではなく、品質タブの
    // 逸脱判定表（ConformityCriteria）の背景にある試験である。
    //
    // **重要**: 判定に使う Table 1 は、下記の公表論文ではなく各試験の
    // プロトコル文書に載っている。論文は試験の設計と結果を報告するもので、
    // 適合性の表そのものは含まない。したがって「この論文を見れば表を
    // 確認できる」と読めてはならない。表の出所は ConformityCriteria の
    // 帰属表示と出典一覧の注記で別に示す（app/docs/data-sources.md §B2）。

    static let rtog0915 = Citation(
        id: "rtog0915", shortLabel: "RTOG 0915",
        authors: "Videtic GM, Hu C, Singh AK, et al.",
        title: "A Randomized Phase 2 Study Comparing 2 Stereotactic Body Radiation Therapy Schedules for Medically Inoperable Patients With Stage I Peripheral Non-Small Cell Lung Cancer: NRG Oncology RTOG 0915 (NCCTG N0927).",
        journal: "Int J Radiat Oncol Biol Phys", year: 2015,
        pmid: "26530743", doi: "10.1016/j.ijrobp.2015.07.2260")

    static let rtog0813 = Citation(
        id: "rtog0813", shortLabel: "RTOG 0813",
        authors: "Bezjak A, Paulus R, Gaspar LE, et al.",
        title: "Safety and Efficacy of a Five-Fraction Stereotactic Body Radiotherapy Schedule for Centrally Located Non-Small-Cell Lung Cancer: NRG Oncology/RTOG 0813 Trial.",
        journal: "J Clin Oncol", year: 2019,
        pmid: "30943123", doi: "10.1200/JCO.18.00622")

    /// 逸脱判定に関わる文献。`all`（線量分割プリセットの出典）とは別に持つ。
    /// 混ぜると、プリセットの出典一覧に判定用の文献が紛れ込む。
    static let conformity: [Citation] = [rtog0915, rtog0813]

    static let all: [Citation] = [
        chhip, startB, fastForward, whelan, jcog0403, jrosg10_1, jcog0303, jcog0909, rtog9005, boneMetsMeta,
        jastroHeadNeck, jastroProstate, jastroBreast, jastroWholeBrain, jastroAcoustic,
        stupp, bonePainTrial
    ]

    /// id から引く。`all`（プリセットの出典）と `conformity`（判定表の背景）の
    /// 両方を探す。片方だけを探すと、呼び出し元が増えたときに黙って nil を返す。
    static func byID(_ id: String) -> Citation? {
        all.first { $0.id == id } ?? conformity.first { $0.id == id }
    }
}
