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

    // MARK: - 書誌情報が未照合のもの（BL-3）

    static let nccnHeadNeck = Citation(
        id: "nccn_hn", shortLabel: "NCCN 頭頸部",
        unsourcedNote: "NCCN Guidelines（頭頸部）に基づく代表的レジメン。版の特定は未了")

    static let jastroProstate = Citation(
        id: "jastro_prostate", shortLabel: "JASTRO 前立腺癌GL",
        unsourcedNote: "JASTRO ガイドラインに基づく代表的レジメン。版の特定は未了")

    static let breastConventional = Citation(
        id: "breast_conventional", shortLabel: "従来標準",
        unsourcedNote: "乳房温存術後の従来標準分割。特定の一次文献に基づかない")

    static let stupp = Citation(
        id: "stupp", shortLabel: "Stupp レジメン",
        unsourcedNote: "Stupp レジメンに基づく。原著の書誌情報は未照合")

    static let bonePainTrial = Citation(
        id: "bone_pain_trial", shortLabel: "Bone Pain Trial",
        unsourcedNote: "Bone Pain Trial Working Party に基づく。原著の書誌情報は未照合")

    // MARK: - 慣用レジメン（BL-1・2026-08-03 決定）
    //
    // 単一の定義的試験を同定できなかった。推測で一次文献を付けない。
    // JASTRO 放射線治療計画ガイドラインを典拠とする案をバックログ BL-1 で検討する。

    static let conventionalRegimen = Citation(
        id: "conventional_regimen", shortLabel: "慣用レジメン",
        unsourcedNote: "広く用いられる慣用レジメン。特定の一次文献に基づかない")

    static let all: [Citation] = [
        chhip, startB, fastForward, whelan, jcog0403, jrosg10_1, jcog0303, jcog0909, rtog9005, boneMetsMeta,
        nccnHeadNeck, jastroProstate, breastConventional, stupp, bonePainTrial,
        conventionalRegimen
    ]

    static func byID(_ id: String) -> Citation? {
        all.first { $0.id == id }
    }
}
