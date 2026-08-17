import Foundation

/// 逸脱の段階。原典 Note 2 により「minor を超えるものは major」。
///
/// 段階名は出典によって使い分ける（仕様 §3.1）。「Per protocol」は RTOG の
/// プロトコル遵守を指す語であり、利用者が自分で登録した基準に対してこの語を
/// 出すのは語の誤用になる。段階そのもの（3 段階の重み付け・色）は出典に
/// よらず共通で、変わるのは表示名だけ。
enum DeviationLevel: String, Sendable {
    case perProtocol
    case minor
    case major

    /// 公表プロトコル（RTOG 0813 / 0915 など）向けの表示名。**これが既定であり、
    /// 挙動を変えてはならない。** 出荷判定に使われている画面がこれを直接
    /// 参照している。
    var displayName: String {
        switch self {
        case .perProtocol: String(localized: "Per protocol")
        case .minor:       String(localized: "Minor deviation")
        case .major:       String(localized: "Major deviation")
        }
    }

    /// 利用者定義の基準向けの表示名（仕様 §3.1）。「基準内 / 基準をやや超える /
    /// 基準を超える」。「逸脱（deviation）」も「プロトコルからの逸脱」を
    /// 含意するので使わない。
    var customDisplayName: String {
        switch self {
        case .perProtocol: String(localized: "基準内")
        case .minor:       String(localized: "基準をやや超える")
        case .major:       String(localized: "基準を超える")
        }
    }
}

/// 判定表の 1 行
struct ConformityRow: Sendable {
    let ptvVolume: Double
    let r50None: Double
    let r50Minor: Double
    let d2cmNone: Double    // 処方線量比 %
    let d2cmMinor: Double   // 処方線量比 %
}

/// PTV 体積に対する許容値
struct ConformityLimits: Sendable, Equatable {
    let r50None: Double
    let r50Minor: Double
    let d2cmNone: Double
    let d2cmMinor: Double
}

/// RTOG 0813 / 0915 の適合性判定表。
///
/// **両プロトコルの Table 1 は完全に同一**であることを原典 PDF の逐字照合で確認済み
/// （app/docs/data-sources.md）。したがって表は 1 つだけ持つ。
/// 0813 は中心型で 5 分割 10〜12 Gy/回、0915 は末梢型で 34 Gy/1 Fr と 48 Gy/4 Fr の
/// 2 群であり、違いは処方線量と OAR 制約にある。0915 を「1〜4 分割」と書くと、
/// 試験が検討していない 2・3 分割を含んでしまう（`ProtocolSelection.studiedSchedules`）。
///
/// 本判定は**公表された表の参照**であり、推奨や指示ではない。
enum ConformityCriteria {

    /// 表の出典表示に使う文字列
    static let sourceLabel = "RTOG 0813 / 0915 Table 1"

    /// 判定表がどこから来たのかの説明。
    ///
    /// **この表は公表論文には載っていない。**論文（RTOG 0813 は J Clin Oncol 2019、
    /// RTOG 0915 は Int J Radiat Oncol Biol Phys 2015）が報告するのは試験の設計と
    /// 結果であり、適合性の表そのものは各試験のプロトコル文書にある。
    /// 「PMID を開けば表を確認できる」と読めてはならないので、由来を明示する。
    static let provenanceNote: LocalizedStringResource = """
        判定表は RTOG 0813 / 0915 のプロトコル文書 Table 1（いずれも p.16「Conformality of \
        Prescribed Dose for Calculations Based on Deposition of Photon Beam Energy in \
        Heterogeneous Tissue」）から転記しています。両プロトコルの表は逐字照合の結果、\
        誤植を含めて完全に同一でした。下に挙げた論文は各試験の設計と結果を報告するもので、\
        この表そのものは含みません。
        """

    /// 判定表が線量分割によらないことの説明。
    ///
    /// 表に載っている量は R100%・R50%（いずれも体積の比）、D2cm・V20（いずれも
    /// 処方線量に対する %）だけで、**絶対線量を一切含まない**。したがって
    /// 34 Gy/1 Fr でも 48 Gy/4 Fr でも同じ表が使える。0813（5 分割 10〜12 Gy/Fr）
    /// と 0915 の表が逐字同一であることの理由でもある。
    ///
    /// 群が併記されていると「どちらの群に対する基準か」が読み取れないので明示する。
    ///
    /// **肺 SBRT（`.builtIn(.rtog0915)` / `.builtIn(.rtog0813)`）専用。**
    /// 「上記のいずれの線量分割にも」は RTOG 0915 / 0813 が検討した線量分割群を
    /// 指しており、頭部定位照射（線量分割という概念自体を持たない。
    /// `BuiltInProtocol.cranialSRS.studiedSchedules` は空配列）には何も指さない
    /// まま漏れてしまう。表示条件は `PlanQualityViewModel.isLungSBRTSelected` に
    /// 集約する（欠陥修正: 以前は `selectedProtocol.summary != nil` という
    /// summary の有無だけを見た緩い条件で表示しており、summary を持つ頭部定位
    /// 照射にも漏れていた）。判定パネルの「この判定基準について」折りたたみに
    /// 格納する（判定結果の読み方そのものは変えない背景説明のため）。
    static let scopeNote: LocalizedStringResource = """
        判定表は体積の比（R100%、R50%）と処方線量に対する割合（D2cm、V20）だけで定義されており、\
        絶対線量を含みません。このため群や線量レベルによらず共通で、上記のいずれの線量分割にも\
        同じ表を用います。
        """

    /// R50% の定義が原典間で食い違っていることと、その解決。
    ///
    /// アプリの計算方法が原典の一方の記述と異なるため、利用者に伝える必要がある。
    /// 0915 の本文どおりに R50% を求めた人は、アプリと違う数値を得る。
    static let r50DefinitionNote: LocalizedStringResource = """
        R50% の定義は原典間で食い違っています。RTOG 0813 は「処方線量の 50% の等線量体積 ÷ PTV 体積」\
        と定義していますが、RTOG 0915 は同じ箇所を「34 Gy または 12 Gy の等線量体積」と記しており、\
        これは第 1 群の全線量と第 2 群の 1 回線量にあたり、いずれも処方線量の 50% になりません。\
        本アプリは、両プロトコルの表の見出し（Ratio of 50% Prescription Isodose Volume to the PTV \
        Volume）と RTOG 0813 の記述に従い、「処方線量の 50% の等線量体積 ÷ PTV 体積」として計算します。
        """

    /// 転記にあたって加えた補正。黙って直すと、原典と突き合わせた人が食い違いに戸惑う。
    static let correctionNote: LocalizedStringResource = """
        原典の 3 箇所（PTV 3.8 cc の R100% Minor、PTV 126.0 / 163.0 cc の D2cm Minor）は \
        不等号の向きが他の全行と逆に記されています。値が単調増加していることから誤植と判断し、\
        他の行に揃えて転記しています。
        """

    /// 体積に依存しない許容値
    static let r100None = 1.2
    static let r100Minor = 1.5
    static let v20None = 10.0
    static let v20Minor = 15.0

    // MARK: - 頭部定位照射（RTOG radiosurgery QA guidelines, Shaw 1993）

    /// 頭部定位照射の判定表の出典表示に使う文字列
    static let cranialSourceLabel = "RTOG radiosurgery QA guidelines (Shaw E, et al. 1993)"

    /// 頭部定位照射の判定基準がどこから来たのかの説明。
    ///
    /// **0813 / 0915 と違い、この基準は公表論文の本文そのものに載っている**
    /// （p.1235「Quality assurance review」節）。プロトコル文書ではなく論文が
    /// 一次情報源であり、`provenanceNote`（0813 / 0915 は「論文はこの表そのものを
    /// 含まない」）と混同されないよう、別に持つ（app/docs/data-sources.md §B6）。
    static let cranialProvenanceNote: LocalizedStringResource = """
        判定基準は Shaw E, et al. Radiation Therapy Oncology Group: radiosurgery quality \
        assurance guidelines. Int J Radiat Oncol Biol Phys. 1993 の本文 p.1235「Quality \
        assurance review」節から逐字転記しています。RTOG 0813 / 0915 の判定表がプロトコル\
        文書にあり論文には載っていないのとは異なり、この判定基準は公表論文の本文そのものに\
        記載されています。
        """

    /// 原典（Shaw 1993）が定める 3 基準のうち、本アプリが判定しない Coverage の明示。
    ///
    /// 元は 1 つの注記だったが、UI 整理（判定パネルの注記が多すぎるという指摘）で
    /// 常時表示すべき部分と折りたためる部分に分割した（`cranialJudgesTwoOfThreeNote` /
    /// `cranialCoverageDetailNote`）。**「2 つだけ判定している」という事実そのものは
    /// 黙って 2 基準だけ判定すると利用者が 3 基準すべてを満たしたと誤解しうるため、
    /// 分割後も必ず常時表示側（`cranialJudgesTwoOfThreeNote`）に残すこと。**
    /// Coverage が何か・なぜ判定できないかという説明は、いま出ている判定結果の
    /// 読み方を変えない背景情報なので折りたたみ側（`cranialCoverageDetailNote`）
    /// に置く。

    /// 前半: 原典が 3 基準を定めているのに本アプリは 2 つしか判定しないという事実。
    /// 判定パネルに常時表示する（`.custom` の帰属文言と同じく、判定がブロックされて
    /// いても消さない）。
    static let cranialJudgesTwoOfThreeNote: LocalizedStringResource = """
        原典は Coverage・Homogeneity index（MDPD）・Conformity index（PITV）の 3 基準を \
        定めていますが、本アプリは MDPD と PITV の 2 つだけを判定します。
        """

    /// 後半: Coverage が何であり、なぜ本アプリが判定できないかの説明。
    /// 判定パネルの「この判定基準について」折りたたみに格納する。
    static let cranialCoverageDetailNote: LocalizedStringResource = """
        Coverage（90% / 80% 等線量線が標的を完全に覆うかの判定）は真偽の判定であり数値指標\
        ではないため、本アプリはこの入力を持たず判定していません。
        """

    /// 原典が定めていない境界を安全側に倒していることの明示（仕様 §2.3）。
    ///
    /// 0813 / 0915 の誤植の補正を明示したのと同じ理由（`correctionNote`）。
    /// 原典と突き合わせた利用者が、境界ちょうどの値で食い違いに戸惑わないようにする。
    static let cranialBoundarySafetyNote: LocalizedStringResource = """
        原典が明示的に定めていない境界（MDPD がちょうど 2.5、PITV がちょうど 0.9 および \
        2.5）は、安全側（重い方の判定段階）に倒しています。原典が明示している境界\
        （MDPD ≦ 2.0、PITV が 1.0 以上 2.0 未満）はそのまま用いています。
        """

    /// 1993 年発表の文書であることの明示（仕様 §2.3 / §4.3）。
    ///
    /// IMRT / VMAT や多発病変への単一アイソセンター照射より前の時代の文書であり、
    /// 現在の実務との関係は利用者が判断すべき情報である。
    ///
    /// **判定パネル（`PlanQualityView`）には表示しない。** `BuiltInProtocol.cranialSRS.summary`
    /// が同じ画面（プロトコル選択直後、判定パネルより上）にほぼ同内容をすでに述べており、
    /// 判定パネルにも重ねて出すと同一情報の重複になる（UI 整理で指摘）。出典一覧
    /// （`CitationListView`）には summary に相当する文が無いため重複せず、そちらでは
    /// 引き続き表示する。
    static let cranialEraNote: LocalizedStringResource = """
        この判定基準は 1993 年発表の文書です。IMRT / VMAT や多発病変への単一\
        アイソセンター照射が普及する前のものであり、現在の実務との関係は利用者が\
        判断してください。
        """

    /// GI (Paddick) の但し書き（仕様 §2.5）。
    ///
    /// 頭部定位照射を選んでいる間だけ、指標カードの GI (Paddick) 行に添える。
    /// **判定の根拠ではなく、指標の限界についての根拠**（根拠は
    /// `Citations.trog2026SRSWorkingGroup`。Shaw 1993 と役割が違うので混同しない）。
    /// 肺 SBRT 選択時・未選択時には出さない（単発病変では不要な文言が常に出ることに
    /// なるため。仕様 §2.5 の議論を参照）。
    static let giCaveatNote: LocalizedStringResource = """
        標的が近接して複数ある場合、この値は意味をなさないことがあります。
        """

    /// Homogeneity index（MDPD = `hiRTOG`）の許容値。片側（大きいほど悪化）。
    /// data-sources.md §B6 の逐字転記から転記: "less than or equal to 2.0" が
    /// per protocol、"greater than 2 but less than 2.5" が minor、
    /// "greater than 2.5" が major。
    ///
    /// **ちょうど 2.0 は原典が明示的に per protocol としている境界**（"less than
    /// **or equal to** 2.0"）。`judge` の上限側は既定で境界を含まない（RTOG の
    /// 表がすべて `<` 表記のため）ので、MDPD の判定では必ず
    /// `upperNoneIsInclusive: true` を渡すこと。渡し忘れると 2.0 ちょうどが
    /// minor に誤判定される（実装時に一度この間違いをして仕様を訂正した。
    /// 仕様 §2.3「境界の包含関係の一覧」参照）。
    ///
    /// **ちょうど 2.5 は原典が定めていない境界**であり、安全側の major に倒れる
    /// （`upperMinor` を含まない既定の規約どおり）。
    static let mdpdUpperNone = 2.0
    static let mdpdUpperMinor = 2.5

    /// Conformity index（PITV = `ciRTOG`）の許容値。両側判定（仕様 §2.2）。
    /// data-sources.md §B6 の逐字転記から転記: "between 1.0 and 2.0" が per protocol、
    /// "less than 1.0 but greater than 0.9" が minor（下側）、"less than 0.9" が major、
    /// "between 2.0 and 2.5" が minor（上側）、"greater than 2.5" が major。
    ///
    /// **下限 1.0 ちょうどは原典が明示的に per protocol としている**境界であり、
    /// `judge` の下限側の既定の規約（`lowerNone` を含む）と一致するので、
    /// 特別な引数は不要。**下限 0.9 ちょうどは原典が定めていない境界**で、
    /// 安全側の major に倒れる（`judge` の下限側は `lowerMinor` を含まない）。
    /// **上限 2.0 ちょうどは原典の記述が曖昧**（"between 1.0 and 2.0" と
    /// "between 2.0 and 2.5" の両方に現れる）で安全側の minor に倒れ、
    /// **上限 2.5 ちょうどは原典が定めていない境界**で安全側の major に倒れる。
    /// いずれも `judge` の上限側の既定（境界を含まない）のままでよく、
    /// MDPD と違って `upperNoneIsInclusive` は不要（`shaw1993PITVBoundaries`
    /// テストで固定済み。ConformityCriteriaTests.swift）。
    static let pitvLowerNone = 1.0
    static let pitvLowerMinor = 0.9
    static let pitvUpperNone = 2.0
    static let pitvUpperMinor = 2.5

    /// 原典 Table 1 の転記。
    /// 原典の誤植 3 箇所（PTV 3.8 の R100% Minor ".<1.5"、PTV 126.0・163.0 の
    /// D2cm Minor ">91.0" ">94.0"）は補正して転記している（app/docs/data-sources.md）。
    static let table: [ConformityRow] = [
        ConformityRow(ptvVolume:   1.8, r50None: 5.9, r50Minor: 7.5, d2cmNone: 50.0, d2cmMinor: 57.0),
        ConformityRow(ptvVolume:   3.8, r50None: 5.5, r50Minor: 6.5, d2cmNone: 50.0, d2cmMinor: 57.0),
        ConformityRow(ptvVolume:   7.4, r50None: 5.1, r50Minor: 6.0, d2cmNone: 50.0, d2cmMinor: 58.0),
        ConformityRow(ptvVolume:  13.2, r50None: 4.7, r50Minor: 5.8, d2cmNone: 50.0, d2cmMinor: 58.0),
        ConformityRow(ptvVolume:  22.0, r50None: 4.5, r50Minor: 5.5, d2cmNone: 54.0, d2cmMinor: 63.0),
        ConformityRow(ptvVolume:  34.0, r50None: 4.3, r50Minor: 5.3, d2cmNone: 58.0, d2cmMinor: 68.0),
        ConformityRow(ptvVolume:  50.0, r50None: 4.0, r50Minor: 5.0, d2cmNone: 62.0, d2cmMinor: 77.0),
        ConformityRow(ptvVolume:  70.0, r50None: 3.5, r50Minor: 4.8, d2cmNone: 66.0, d2cmMinor: 86.0),
        ConformityRow(ptvVolume:  95.0, r50None: 3.3, r50Minor: 4.4, d2cmNone: 70.0, d2cmMinor: 89.0),
        ConformityRow(ptvVolume: 126.0, r50None: 3.1, r50Minor: 4.0, d2cmNone: 73.0, d2cmMinor: 91.0),
        ConformityRow(ptvVolume: 163.0, r50None: 2.9, r50Minor: 3.7, d2cmNone: 77.0, d2cmMinor: 94.0)
    ]

    /// PTV 体積に対する許容値。
    ///
    /// 原典 Note 1「For values of PTV dimension or volume not specified,
    /// linear interpolation between table entries is required.」に従い線形補間する。
    /// 表の範囲外では原典に規定がないため外挿せず nil を返す。
    static func limits(ptvVolume v: Double) -> ConformityLimits? {
        guard let first = table.first, let last = table.last else { return nil }
        guard v >= first.ptvVolume, v <= last.ptvVolume else { return nil }

        // 完全一致する行があればそのまま返す
        if let exact = table.first(where: { $0.ptvVolume == v }) {
            return ConformityLimits(
                r50None: exact.r50None, r50Minor: exact.r50Minor,
                d2cmNone: exact.d2cmNone, d2cmMinor: exact.d2cmMinor)
        }

        // v を挟む 2 行を探して線形補間
        for i in 0..<(table.count - 1) {
            let lo = table[i]
            let hi = table[i + 1]
            guard v > lo.ptvVolume, v < hi.ptvVolume else { continue }
            let t = (v - lo.ptvVolume) / (hi.ptvVolume - lo.ptvVolume)
            return ConformityLimits(
                r50None:  lo.r50None  + t * (hi.r50None  - lo.r50None),
                r50Minor: lo.r50Minor + t * (hi.r50Minor - lo.r50Minor),
                d2cmNone: lo.d2cmNone + t * (hi.d2cmNone - lo.d2cmNone),
                d2cmMinor: lo.d2cmMinor + t * (hi.d2cmMinor - lo.d2cmMinor))
        }
        return nil
    }

    /// 値を許容値と照合する。表の表記が `<` のため境界値は厳密に判定する。
    ///
    /// **この関数の挙動を変えてはならない。** RTOG 0813 / 0915 の判定表
    /// （出荷判定に使われている）が直接呼んでいる（`PlanQualityViewModel`）。
    /// 片側判定（値が小さいほど良い）のみを扱う。両側判定が要る場合は
    /// 下の `judge(value:upperNone:upperMinor:lowerNone:lowerMinor:)` を使う
    /// （この関数はそちらの内部実装としても使われる）。
    static func judge(value: Double, none: Double, minor: Double) -> DeviationLevel {
        if value < none { return .perProtocol }
        if value < minor { return .minor }
        return .major
    }

    /// 値を許容範囲と照合する（両側判定）。
    ///
    /// RTOG 0813 / 0915 の判定表はすべて片側（値が小さいほど良い）だが、
    /// 頭部定位照射の判定基準（Shaw 1993 の PITV 等）や利用者定義の基準には
    /// 両側（下限・上限の両方を持つ）ものがある。この関数は D2（自施設の
    /// 判定基準）専用ではなく、両側判定を要る経路すべてで共通に使う
    /// （仕様 §2.3）。
    ///
    /// - 上限側（`value` が小さいほど良い方向）: `upperNone` 未満なら基準内。
    ///   `upperMinor` を指定すると、`upperNone` 以上 `upperMinor` 未満は
    ///   minor、`upperMinor` 以上は major の 3 段階になる。`upperMinor` を
    ///   省略すると、`upperNone` 未満か否かだけの 2 段階（基準内 / major）
    ///   になる。境界の扱いは `judge(value:none:minor:)` と同じ（`<` で
    ///   厳密に判定する。ちょうど `upperNone` は基準内に含まれない）。
    /// - 下限側（`value` が大きいほど良い方向）: `lowerNone` **以上**なら
    ///   基準内（上限側と非対称で、`lowerNone` ちょうどを含む）。`lowerMinor`
    ///   を指定すると、`lowerMinor` 未満は major、`lowerMinor` 以上
    ///   `lowerNone` 未満は minor の 3 段階になる。省略すると 2 段階になる。
    ///
    ///   **上限は既定で境界を含まず、下限は境界を含む。この非対称は意図的。**
    ///   仕様上「境界は安全側（重い方）に倒す」のは原典が値を定めていない
    ///   境界だけであり、原典が明示している境界にはそのまま従う。Shaw 1993
    ///   の PITV は「between 1.0 and 2.0 で per protocol」「1.0 未満
    ///   （0.9 より大きい）が minor」と明示しており、`lowerNone`（1.0）
    ///   ちょうどは per protocol、`lowerMinor`（0.9）ちょうどは原典が
    ///   定めていないので安全側に倒して major になる。
    /// - `upperNoneIsInclusive`: **既定は `false`（含まない）で変えてはならない。**
    ///   RTOG 0813 / 0915 の表はすべて `<` 表記であり、既定を変えるとそちらの
    ///   判定が動く（仕様 §2.3「境界の包含関係の一覧」）。Shaw 1993 の MDPD は
    ///   例外で "less than or equal to 2.0" と原典が明示的に**含める**書き方を
    ///   しているため、`true` を渡すとちょうど `upperNone` が per protocol になる。
    ///   下限側に対応する引数は無い。下限は既に既定で「含む」であり、対応する
    ///   引数を足しても常に無指定と同じ意味にしかならない（使わない抽象は
    ///   害になりうる。plan 2026-08-15-pocketrt-cranial-srs-protocol.md）。
    /// - 上限・下限は独立に指定でき、どちらも省略できる。両方指定した場合は
    ///   両側とも判定し、悪い方の段階を返す。
    /// - 上限・下限のどちらも指定しない場合は判定できないので `nil` を返す。
    ///   呼び出し側はこれを「この指標は判定しない」の意味に使ってよい
    ///   （0 や「基準内」にしてはならない。仕様 §2.2 / §4.4 系の要件）。
    static func judge(value: Double,
                       upperNone: Double? = nil, upperMinor: Double? = nil,
                       upperNoneIsInclusive: Bool = false,
                       lowerNone: Double? = nil, lowerMinor: Double? = nil) -> DeviationLevel? {
        guard upperNone != nil || lowerNone != nil else { return nil }

        var level = DeviationLevel.perProtocol

        if let upperNone {
            let upperLevel: DeviationLevel
            let isWithinNone = upperNoneIsInclusive ? value <= upperNone : value < upperNone
            if let upperMinor {
                upperLevel = isWithinNone ? .perProtocol : (value < upperMinor ? .minor : .major)
            } else {
                upperLevel = isWithinNone ? .perProtocol : .major
            }
            level = worse(level, upperLevel)
        }

        if let lowerNone {
            // 下限側は上限側の単純な鏡像ではない。`lowerNone` は含む
            // （`value >= lowerNone` が基準内）。上限側と違い符号反転による
            // 再利用はできないため、書き下す。
            let lowerLevel: DeviationLevel
            if value >= lowerNone {
                lowerLevel = .perProtocol
            } else if let lowerMinor, value > lowerMinor {
                lowerLevel = .minor
            } else {
                lowerLevel = .major
            }
            level = worse(level, lowerLevel)
        }

        return level
    }

    /// 2 つの段階のうち、より重い方を返す（perProtocol < minor < major）。
    private static func worse(_ a: DeviationLevel, _ b: DeviationLevel) -> DeviationLevel {
        severityRank(a) >= severityRank(b) ? a : b
    }

    private static func severityRank(_ level: DeviationLevel) -> Int {
        switch level {
        case .perProtocol: 0
        case .minor: 1
        case .major: 2
        }
    }
}
