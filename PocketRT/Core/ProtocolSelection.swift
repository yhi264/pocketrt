import Foundation

/// プロトコルが実際に検討した線量分割の 1 つ。
///
/// 判定表そのものは比と割合だけでできており線量分割によらない
/// （`ConformityCriteria.scopeNote`）。それでも線量を検査するのは、
/// 逸脱判定が**プロトコルへの適合の判断**だからである。その試験が
/// 一度も検討していない線量分割に対して「Per protocol」と表示するのは、
/// 表が幾何学的に適用できるかどうかとは別の問題である。
struct StudiedSchedule: Sendable, Hashable {
    let fractions: Int
    /// 1 回線量の範囲。単一の線量だけを検討した群は下限と上限が同じ。
    let dosePerFraction: ClosedRange<Double>

    /// 入力の丸めを吸収する幅（Gy/回）。
    /// 48.0 / 4 が 11.999999… になる程度のずれだけを許す。
    static let tolerance = 0.05

    func matches(fractions n: Int, dosePerFraction d: Double) -> Bool {
        n == fractions
            && d >= dosePerFraction.lowerBound - Self.tolerance
            && d <= dosePerFraction.upperBound + Self.tolerance
    }

    /// 「34 Gy/1 Fr」「50〜60 Gy/5 Fr」のような、一覧に併記する短い表示
    var compactLabel: String {
        let lo = dosePerFraction.lowerBound
        let hi = dosePerFraction.upperBound
        let totalLo = DoseFormat.doseString(lo * Double(fractions))
        if lo == hi {
            return String(localized: "\(totalLo) Gy/\(fractions) Fr")
        }
        let totalHi = DoseFormat.doseString(hi * Double(fractions))
        return String(localized: "\(totalLo)〜\(totalHi) Gy/\(fractions) Fr")
    }

    /// 「48 Gy（12 Gy/回）」「50〜60 Gy（10〜12 Gy/回）」のような表示
    var label: String {
        let lo = dosePerFraction.lowerBound
        let hi = dosePerFraction.upperBound
        let totalLo = lo * Double(fractions)
        let totalHi = hi * Double(fractions)
        // String(format:) はカタログを引かないため、書式そのものが日本語で
        // 固定される（「Gy/回」が英語環境にも出ていた。2026-09-05）。
        // String(localized:) にして、書式ごと訳せるようにする。
        if lo == hi {
            let total = DoseFormat.doseString(totalLo)
            let perFraction = DoseFormat.doseString(lo)
            return String(localized: "\(total) Gy（\(perFraction) Gy/回）")
        }
        let totalLoText = DoseFormat.doseString(totalLo)
        let totalHiText = DoseFormat.doseString(totalHi)
        let loText = DoseFormat.doseString(lo)
        let hiText = DoseFormat.doseString(hi)
        return String(localized: "\(totalLoText)〜\(totalHiText) Gy（\(loText)〜\(hiText) Gy/回）")
    }
}

/// 内蔵の逸脱判定プロトコル（RTOG 0915 / 0813）。分割数から自動推定はしない。
///
/// `ProtocolSelection.builtIn` が保持する。出典・対象集団・検討された線量分割を
/// 持つのはこの型だけで、`ProtocolSelection.custom`（利用者定義）は持てない
/// （`CustomProtocol` 自体にこれらのフィールドが無いため、型として持てない。
/// 仕様 §4.1 / §5、D1 の `InstitutionalPreset` が出典を持てないのと同じ理由）。
enum BuiltInProtocol: String, CaseIterable, Identifiable, Sendable {
    case rtog0915
    case rtog0813
    /// 頭部定位照射（RTOG radiosurgery QA guidelines, Shaw 1993）。
    ///
    /// 0813 / 0915 と違い特定の線量分割に紐づく臨床試験ではなく、QA の枠組みである
    /// （`studiedSchedules` が空。仕様 §3.1）。PTV 体積にも依存しない（仕様 §3.2）。
    case cranialSRS

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rtog0915: String(localized: "RTOG 0915（末梢型肺）")
        case .rtog0813: String(localized: "RTOG 0813（中心型肺）")
        case .cranialSRS: String(localized: "頭部定位照射（RTOG QA ガイドライン）")
        }
    }

    /// プロトコルが実際に検討した線量分割。
    ///
    /// 分割数と 1 回線量を別々に持つと、どの群にも存在しない組み合わせ
    /// （例: RTOG 0915 で「4 分割かつ 34 Gy」）を通してしまう。
    /// 検討された線量分割そのものを組で持つ。
    var studiedSchedules: [StudiedSchedule] {
        switch self {
        case .rtog0915:
            // 第 1 群 34 Gy/1 Fr、第 2 群 48 Gy/4 Fr。2 分割と 3 分割は検討されていない
            [StudiedSchedule(fractions: 1, dosePerFraction: 34.0...34.0),
             StudiedSchedule(fractions: 4, dosePerFraction: 12.0...12.0)]
        case .rtog0813:
            // 5 分割固定。線量漸増は 1 回線量で行われ、10〜12 Gy/回（MTD 12.0）
            [StudiedSchedule(fractions: 5, dosePerFraction: 10.0...12.0)]
        case .cranialSRS:
            // 特定の線量分割を検討した臨床試験ではなく QA の枠組みなので、
            // 分割数・線量による適用範囲の検査は行わない（仕様 §3.1）。
            []
        }
    }

    /// プロトコルが実際に検討した分割数
    var expectedFractions: Set<Int> { Set(studiedSchedules.map(\.fractions)) }

    /// 「1 または 4」のような表示。何分割なら一致するのかを利用者に示す。
    var expectedFractionsLabel: String {
        expectedFractions.sorted().map(String.init)
            .formatted(.list(type: .or, width: .narrow))
    }

    /// 選択肢に併記する線量分割。「34 Gy/1 Fr・48 Gy/4 Fr」の形。
    ///
    /// 試験番号と部位だけでは、その選択肢が自分の症例に当てはまるかを
    /// 選ぶ時点で判断できない。`studiedSchedules` から導くので、
    /// 検討された線量分割を直せばこの表示も追随する。
    var selectionDetail: String {
        studiedSchedules.map(\.compactLabel)
            .joined(separator: String(localized: "・", comment: "検討された線量分割どうしの区切り"))
    }

    /// プルダウンの各行に出す文字列。部位と線量分割を 1 行にまとめる。
    ///
    /// 畳んだときは `displayName` だけを出すので、ここが長くても
    /// 選択後の表示は短いままになる。`selectionDetail` が空（頭部定位照射のように
    /// 検討された線量分割を持たないプロトコル）のときは、末尾に余計な空白を
    /// 残さない。
    var menuLabel: String {
        selectionDetail.isEmpty ? displayName : "\(displayName)  \(selectionDetail)"
    }

    /// 何を調べた試験なのかを 1 行で示す。
    ///
    /// 名前と分割数だけでは、その表が自分の症例に当てはまるかを判断できない。
    /// 対象集団と検討された線量分割を出す。詳しい書誌情報と、判定表が
    /// 論文ではなくプロトコル文書に由来することは出典一覧で示す。
    var summary: LocalizedStringResource {
        switch self {
        case .rtog0915:
            "対象は手術不能の末梢型（中枢気管支から 2 cm 以上）T1-2 N0M0 非小細胞肺癌。34 Gy/1 Fr（第 1 群）と 48 Gy/4 Fr（第 2 群）を比較した第 2 相ランダム化試験。"
        case .rtog0813:
            "対象は手術不能の中心型 T1-2（5 cm 以下）N0M0 非小細胞肺癌。10〜12 Gy/Fr の 5 分割で線量漸増した第 1/2 相試験。最大耐容線量は 12.0 Gy/Fr。"
        case .cranialSRS:
            "対象は頭部への定位放射線照射（SRS/SRT）全般。特定の線量分割や臨床試験に紐づかない RTOG の QA の枠組みで、1993 年発表。IMRT/VMAT や多発病変への単一アイソセンター照射が普及する前の文書であり、現在の実務との関係は利用者が判断する。"
        }
    }

    /// 判定表の背景にある文献。
    var citations: [Citation] {
        switch self {
        case .rtog0915: [Citations.rtog0915]
        case .rtog0813: [Citations.rtog0813]
        case .cranialSRS: [Citations.shaw1993]
        }
    }
}

/// 逸脱判定に用いるプロトコルの選択結果。
///
/// D1 の `PresetSelection` と同じ構造にしている。内蔵と利用者定義のどちらから
/// 来たかを型で保つ。出典・対象集団・検討された線量分割（`citations` /
/// `summary` / `studiedSchedules` / `selectionDetail`）は `builtIn` だけが
/// 持つ。`custom` はこれらを型として持てない（`CustomProtocol` 自体に
/// フィールドが無い）。実行時のガードではなく、型の構造でこれを保証する。
/// 持てる形にすると、出典のないものに出典欄が生まれる（D1 で自施設
/// プリセットが出典を持てない形にしたのと同じ理由。仕様 §5）。
enum ProtocolSelection: Identifiable, Equatable, Sendable {
    case none
    case builtIn(BuiltInProtocol)
    /// `CustomProtocol.id`。**値のコピーではなく id を持つ。** 選択後に対象が
    /// 削除・編集されても判定が古い内容のまま出続ける事故を防ぐため
    /// （外部レビューで検出。値を持たせていたときは、削除しても一覧からは
    /// 消えるのに判定は消えたプロトコルの閾値で出続け、編集しても判定が
    /// 古い閾値のままだった）。実際の内容は `PlanQualityViewModel` が
    /// `customProtocols` から都度 id で引く。この型単体では名前も閾値も
    /// 解決できない。
    case custom(String)

    var id: String {
        switch self {
        case .none: "none"
        case .builtIn(let p): "builtin_\(p.rawValue)"
        case .custom(let id): "custom_\(id)"
        }
    }

    /// `custom` は id しか持たないため、実際の名前を解決できない。
    /// 呼び出し側が名前を必要とする場合（判定パネルの見出し等）は
    /// `PlanQualityViewModel.selectedProtocolDisplayName` を使うこと。
    /// ここでの `custom` の値は、削除されていない前提でも実名を返せない
    /// ことを示す汎用の文言であり、UI にそのまま出すことは想定していない。
    var displayName: String {
        switch self {
        case .none: String(localized: "判定しない")
        case .builtIn(let p): p.displayName
        case .custom: String(localized: "自施設の基準")
        }
    }

    /// `builtIn` だけが持つ。`custom`（検討された線量分割という概念が無い）
    /// と `none` は `nil`。
    var studiedSchedules: [StudiedSchedule]? {
        switch self {
        case .none, .custom: nil
        case .builtIn(let p): p.studiedSchedules
        }
    }

    var expectedFractions: Set<Int>? {
        guard let schedules = studiedSchedules else { return nil }
        return Set(schedules.map(\.fractions))
    }

    var expectedFractionsLabel: String? {
        guard let expected = expectedFractions else { return nil }
        return expected.sorted().map(String.init)
            .formatted(.list(type: .or, width: .narrow))
    }

    /// `builtIn` だけが持つ。`custom` に持たせると、出典のないものに
    /// 検討された線量分割の表示が生まれる。
    var selectionDetail: String? {
        switch self {
        case .none, .custom: nil
        case .builtIn(let p): p.selectionDetail
        }
    }

    /// プルダウンの各行に出す文字列。`custom` は線量分割の併記が無いので
    /// `displayName`（利用者が付けた名前）のみ。
    var menuLabel: String {
        switch self {
        case .none, .custom: displayName
        case .builtIn(let p): p.menuLabel
        }
    }

    /// `builtIn` だけが持つ。`custom` に持たせると、出典のないものに
    /// 対象集団・試験デザインの説明が生まれる。
    var summary: LocalizedStringResource? {
        switch self {
        case .none, .custom: nil
        case .builtIn(let p): p.summary
        }
    }

    /// 判定表の背景にある文献。`builtIn` だけが持つ。`custom` は出典を
    /// 持ちえない（`CustomProtocol` 自体に citations フィールドが無い）ので
    /// 常に空。D1 の自施設プリセットと同じ扱い。
    var citations: [Citation] {
        switch self {
        case .none, .custom: []
        case .builtIn(let p): p.citations
        }
    }
}
