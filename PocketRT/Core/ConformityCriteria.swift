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
/// 0813 は中心型・5 分割、0915 は末梢型・1〜4 分割で、違いは処方線量と OAR 制約にある。
///
/// 本判定は**公表された表の参照**であり、推奨や指示ではない。
enum ConformityCriteria {

    /// 表の出典表示に使う文字列
    static let sourceLabel = "RTOG 0813 / 0915 Table 1"

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
