import Foundation

/// 逸脱の段階。原典 Note 2 により「minor を超えるものは major」。
enum DeviationLevel: String, Sendable {
    case perProtocol
    case minor
    case major

    var displayName: String {
        switch self {
        case .perProtocol: String(localized: "Per protocol")
        case .minor:       String(localized: "Minor deviation")
        case .major:       String(localized: "Major deviation")
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
    static func judge(value: Double, none: Double, minor: Double) -> DeviationLevel {
        if value < none { return .perProtocol }
        if value < minor { return .minor }
        return .major
    }
}
