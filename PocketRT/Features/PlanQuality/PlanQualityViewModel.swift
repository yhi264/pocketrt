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

    /// プロトコルが想定する分割数
    var expectedFractions: ClosedRange<Int>? {
        switch self {
        case .none:     nil
        case .rtog0915: 1...4
        case .rtog0813: 5...5
        }
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
        if let expected = selectedProtocol.expectedFractions, let n = fractions, !expected.contains(n) {
            return String(localized: "選択したプロトコルの分割数と一致しません")
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
        if let expected = selectedProtocol.expectedFractions, let n = fractions, !expected.contains(n) {
            return .outsideProtocolScope
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
