import Foundation

/// 逸脱判定に用いるプロトコル。分割数から自動推定はしない。
enum ProtocolSelection: String, CaseIterable, Identifiable, Sendable {
    case none
    case rtog0915
    case rtog0813

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:     String(localized: "判定しない")
        case .rtog0915: String(localized: "RTOG 0915（末梢型肺）")
        case .rtog0813: String(localized: "RTOG 0813（中心型肺）")
        }
    }

    /// プロトコルが実際に検討した線量分割。
    ///
    /// 分割数と 1 回線量を別々に持つと、どの群にも存在しない組み合わせ
    /// （例: RTOG 0915 で「4 分割かつ 34 Gy」）を通してしまう。
    /// 検討された線量分割そのものを組で持つ。
    var studiedSchedules: [StudiedSchedule]? {
        switch self {
        case .none:
            nil
        case .rtog0915:
            // 第 1 群 34 Gy/1 Fr、第 2 群 48 Gy/4 Fr。2 分割と 3 分割は検討されていない
            [StudiedSchedule(fractions: 1, dosePerFraction: 34.0...34.0),
             StudiedSchedule(fractions: 4, dosePerFraction: 12.0...12.0)]
        case .rtog0813:
            // 5 分割固定。線量漸増は 1 回線量で行われ、10〜12 Gy/回（MTD 12.0）
            [StudiedSchedule(fractions: 5, dosePerFraction: 10.0...12.0)]
        }
    }

    /// プロトコルが実際に検討した分割数
    var expectedFractions: Set<Int>? {
        guard let schedules = studiedSchedules else { return nil }
        return Set(schedules.map(\.fractions))
    }

    /// 「1 または 4」のような表示。何分割なら一致するのかを利用者に示す。
    var expectedFractionsLabel: String? {
        guard let expected = expectedFractions else { return nil }
        return expected.sorted().map(String.init)
            .formatted(.list(type: .or, width: .narrow))
    }

    /// 選択肢に併記する線量分割。「34 Gy/1 Fr・48 Gy/4 Fr」の形。
    ///
    /// 試験番号と部位だけでは、その選択肢が自分の症例に当てはまるかを
    /// 選ぶ時点で判断できない。`studiedSchedules` から導くので、
    /// 検討された線量分割を直せばこの表示も追随する。
    var selectionDetail: String? {
        guard let schedules = studiedSchedules, !schedules.isEmpty else { return nil }
        return schedules.map(\.compactLabel).joined(separator: "・")
    }

    /// プルダウンの各行に出す文字列。部位と線量分割を 1 行にまとめる。
    ///
    /// 畳んだときは `displayName` だけを出すので、ここが長くても
    /// 選択後の表示は短いままになる。
    var menuLabel: String {
        guard let detail = selectionDetail else { return displayName }
        return "\(displayName)  \(detail)"
    }

    /// 何を調べた試験なのかを 1 行で示す。
    ///
    /// 名前と分割数だけでは、その表が自分の症例に当てはまるかを判断できない。
    /// 対象集団と検討された線量分割を出す。詳しい書誌情報と、判定表が
    /// 論文ではなくプロトコル文書に由来することは出典一覧で示す。
    var summary: LocalizedStringResource? {
        switch self {
        case .none:
            nil
        case .rtog0915:
            "対象は手術不能の末梢型（中枢気管支から 2 cm 以上）T1-2 N0M0 非小細胞肺癌。34 Gy/1 Fr（第 1 群）と 48 Gy/4 Fr（第 2 群）を比較した第 2 相ランダム化試験。"
        case .rtog0813:
            "対象は手術不能の中心型 T1-2（5 cm 以下）N0M0 非小細胞肺癌。10〜12 Gy/Fr の 5 分割で線量漸増した第 1/2 相試験。最大耐容線量は 12.0 Gy/Fr。"
        }
    }

    /// 判定表の背景にある文献。`.none` では判定しないので空。
    var citations: [Citation] {
        switch self {
        case .none:     []
        case .rtog0915: [Citations.rtog0915]
        case .rtog0813: [Citations.rtog0813]
        }
    }
}

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
            return "\(totalLo) Gy/\(fractions) Fr"
        }
        let totalHi = DoseFormat.doseString(hi * Double(fractions))
        return "\(totalLo)〜\(totalHi) Gy/\(fractions) Fr"
    }

    /// 「48 Gy（12 Gy/回）」「50〜60 Gy（10〜12 Gy/回）」のような表示
    var label: String {
        let lo = dosePerFraction.lowerBound
        let hi = dosePerFraction.upperBound
        let totalLo = lo * Double(fractions)
        let totalHi = hi * Double(fractions)
        if lo == hi {
            return String(format: "%@ Gy（%@ Gy/回）",
                          DoseFormat.doseString(totalLo), DoseFormat.doseString(lo))
        }
        return String(format: "%@〜%@ Gy（%@〜%@ Gy/回）",
                      DoseFormat.doseString(totalLo), DoseFormat.doseString(totalHi),
                      DoseFormat.doseString(lo), DoseFormat.doseString(hi))
    }
}

@Observable
final class PlanQualityViewModel {

    // 入力（文字列で保持し、Double? に変換する）
    var tvText = ""            // PTV 体積 (cc)
    var rxText = ""            // 処方線量 (Gy)
    var pivText = ""           // 処方等線量体積 (cc)
    var tvPIVText = ""         // PTV 内で処方線量以上の体積 (cc)
    var v50Text = ""           // 50% 等線量体積 (cc)
    var dmaxText = ""          // 最大線量 (Gy)
    var d2Text = ""            // D2% (Gy)
    var d98Text = ""           // D98% (Gy)
    var d50Text = ""           // D50% (Gy)
    var d2cmText = ""          // PTV から 2cm 外側の最大線量 (Gy)
    var fractionsText = ""     // 分割数
    var selectedProtocol: ProtocolSelection = .none

    // 正の値のみ受け付ける。0・負値・非数値・非有限（inf/nan）は nil
    //
    // Double("1e309") や Double("inf") は +∞ を返し、∞ > 0 は真になるため
    // isFinite の確認が必須。TPS からの DVH 値ペーストで到達しうる。
    private func positive(_ s: String) -> Double? {
        guard let v = Double(s), v.isFinite, v > 0 else { return nil }
        return v
    }

    var tv: Double? { positive(tvText) }
    var rx: Double? { positive(rxText) }
    var piv: Double? { positive(pivText) }
    var tvPIV: Double? { positive(tvPIVText) }
    var v50: Double? { positive(v50Text) }
    var dmax: Double? { positive(dmaxText) }
    var d2: Double? { positive(d2Text) }
    var d98: Double? { positive(d98Text) }
    var d50: Double? { positive(d50Text) }
    var d2cmDose: Double? { positive(d2cmText) }
    var fractions: Int? {
        guard let n = Int(fractionsText), n > 0 else { return nil }
        return n
    }

    func error(for text: String, value: Double?) -> String? {
        guard !text.isEmpty else { return nil }
        return value == nil ? String(localized: "正の数値を入力") : nil
    }

    // 矛盾検出
    var issues: [PlanQualityIssue] {
        PlanQualityIndices.issues(
            tv: tv, piv: piv, tvPIV: tvPIV, v50: v50, d2: d2, d98: d98, d50: d50)
    }

    // 指標。入力が揃わないものは nil
    var ciRTOG: Double? {
        guard let piv, let tv else { return nil }
        return PlanQualityIndices.conformityIndexRTOG(piv: piv, tv: tv)
    }
    var ciPaddick: Double? {
        guard let tvPIV, let tv, let piv else { return nil }
        return PlanQualityIndices.conformityIndexPaddick(tvPIV: tvPIV, tv: tv, piv: piv)
    }
    var hiRTOG: Double? {
        guard let dmax, let rx else { return nil }
        return PlanQualityIndices.homogeneityIndexRTOG(maxDose: dmax, prescriptionDose: rx)
    }
    var hiICRU83: Double? {
        guard let d2, let d98, let d50 else { return nil }
        return PlanQualityIndices.homogeneityIndexICRU83(d2: d2, d98: d98, d50: d50)
    }
    var r50Value: Double? {
        guard let v50, let tv else { return nil }
        return PlanQualityIndices.r50(v50: v50, tv: tv)
    }
    var giPaddick: Double? {
        guard let v50, let piv else { return nil }
        return PlanQualityIndices.gradientIndexPaddick(v50: v50, piv: piv)
    }
    var d2cmValue: Double? {
        guard let d2cmDose, let rx else { return nil }
        return PlanQualityIndices.d2cmPercent(d2cmDose: d2cmDose, prescriptionDose: rx)
    }

    // MARK: - 逸脱判定

    /// 判定を出せない理由の種別。
    ///
    /// 「入力が足りない」と「公表プロトコルがこの計画を扱っていない」は
    /// 臨床的に別のことなので、同じ見え方にしない。
    enum JudgementBlockKind: Sendable {
        /// 入力を足せば解決する
        case incompleteInput
        /// 入力を足しても解決しない。公表プロトコルの適用範囲外
        case outsideProtocolScope
    }

    /// 判定が適用できない理由。nil なら適用できる。
    var judgementBlockedReason: String? {
        if selectedProtocol == .none {
            return String(localized: "プロトコルが選択されていません")
        }
        guard let tv else {
            return String(localized: "PTV 体積が未入力です")
        }
        guard ConformityCriteria.limits(ptvVolume: tv) != nil else {
            let lower = ConformityCriteria.table.first?.ptvVolume ?? 0
            let upper = ConformityCriteria.table.last?.ptvVolume ?? 0
            return String(localized: "PTV 体積が表の範囲（\(lower, specifier: "%.1f")〜\(upper, specifier: "%.1f") cc）外のため判定できません")
        }
        if let schedules = selectedProtocol.studiedSchedules, let n = fractions {
            // 何が一致しないのかを分けて伝える。「一致しません」だけでは、
            // 入力を直せばよいのか、そもそも別のプロトコルを選ぶべきなのかが
            // 判断できない。
            let sameFractions = schedules.filter { $0.fractions == n }
            if sameFractions.isEmpty {
                let label = selectedProtocol.expectedFractionsLabel ?? ""
                return String(localized: "このプロトコルが検討したのは \(label) 分割です。入力は \(n) 分割のため判定できません")
            }
            // 分割数は合っている。次に 1 回線量を見る
            if let rx, rx > 0 {
                let perFraction = rx / Double(n)
                if !sameFractions.contains(where: { $0.matches(fractions: n, dosePerFraction: perFraction) }) {
                    let studied = sameFractions.map(\.label).formatted(.list(type: .or, width: .narrow))
                    return String(localized: "このプロトコルが \(n) 分割で検討したのは \(studied)です。入力は \(DoseFormat.doseString(rx)) Gy（\(DoseFormat.doseString(perFraction)) Gy/回）のため判定できません")
                }
            }
        }
        if fractions == nil {
            return String(localized: "分割数が未入力です")
        }
        if !issues.isEmpty {
            return String(localized: "入力に矛盾があるため判定できません")
        }
        return nil
    }

    /// `judgementBlockedReason` の種別。両者はブロックの有無について必ず一致する。
    var judgementBlockKind: JudgementBlockKind? {
        if selectedProtocol == .none {
            return .incompleteInput
        }
        guard let tv else {
            return .incompleteInput
        }
        guard ConformityCriteria.limits(ptvVolume: tv) != nil else {
            return .outsideProtocolScope
        }
        // 分割数・線量のいずれが外れていても、入力を足しても解決しないので
        // 適用範囲外。判定できない理由の生成と同じ条件で分岐させる。
        if let schedules = selectedProtocol.studiedSchedules, let n = fractions {
            let sameFractions = schedules.filter { $0.fractions == n }
            if sameFractions.isEmpty {
                return .outsideProtocolScope
            }
            if let rx, rx > 0 {
                let perFraction = rx / Double(n)
                if !sameFractions.contains(where: { $0.matches(fractions: n, dosePerFraction: perFraction) }) {
                    return .outsideProtocolScope
                }
            }
        }
        if fractions == nil {
            return .incompleteInput
        }
        if !issues.isEmpty {
            return .incompleteInput
        }
        return nil
    }

    var limits: ConformityLimits? {
        guard judgementBlockedReason == nil, let tv else { return nil }
        return ConformityCriteria.limits(ptvVolume: tv)
    }

    var r50Deviation: DeviationLevel? {
        guard let limits, let v = r50Value else { return nil }
        return ConformityCriteria.judge(value: v, none: limits.r50None, minor: limits.r50Minor)
    }

    var d2cmDeviation: DeviationLevel? {
        guard let limits, let v = d2cmValue else { return nil }
        return ConformityCriteria.judge(value: v, none: limits.d2cmNone, minor: limits.d2cmMinor)
    }

    var r100Deviation: DeviationLevel? {
        guard judgementBlockedReason == nil, let v = ciRTOG else { return nil }
        return ConformityCriteria.judge(
            value: v, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor)
    }
}
