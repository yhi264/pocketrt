import Foundation

/// 入力の物理的な矛盾
enum PlanQualityIssue: String, CaseIterable, Sendable {
    case tvPIVExceedsTV
    case tvPIVExceedsPIV
    case d98ExceedsD2
    case d50OutOfRange
    case v50LessThanPIV

    var message: String {
        switch self {
        case .tvPIVExceedsTV:
            String(localized: "PTV 内で処方線量以上の体積が PTV 体積を超えています")
        case .tvPIVExceedsPIV:
            String(localized: "PTV 内で処方線量以上の体積が処方等線量体積を超えています")
        case .d98ExceedsD2:
            String(localized: "D98% が D2% を超えています")
        case .d50OutOfRange:
            String(localized: "D50% が D98%〜D2% の範囲外です")
        case .v50LessThanPIV:
            String(localized: "50% 等線量体積が処方等線量体積より小さくなっています")
        }
    }
}

/// SBRT / SRS のプラン品質指標。
///
/// 必要な入力が揃わない指標は `nil` を返す。0 として計算しない。
/// 定義は複数あるため、呼び出し側は必ず定義名を併記して表示すること。
enum PlanQualityIndices {

    /// 非有限（inf / nan）は指標として返さない。
    /// 入力が有限でも、極端な値の組み合わせで演算結果が非有限になりうる。
    private static func finite(_ v: Double) -> Double? {
        v.isFinite ? v : nil
    }

    /// CI(RTOG) = PIV / TV
    static func conformityIndexRTOG(piv: Double, tv: Double) -> Double? {
        guard piv > 0, tv > 0 else { return nil }
        return finite(piv / tv)
    }

    /// CI(Paddick) = TV_PIV² / (TV × PIV)
    static func conformityIndexPaddick(tvPIV: Double, tv: Double, piv: Double) -> Double? {
        guard tvPIV >= 0, tv > 0, piv > 0 else { return nil }
        return finite((tvPIV * tvPIV) / (tv * piv))
    }

    /// HI(RTOG) = Dmax / Rx
    static func homogeneityIndexRTOG(maxDose: Double, prescriptionDose rx: Double) -> Double? {
        guard maxDose > 0, rx > 0 else { return nil }
        return finite(maxDose / rx)
    }

    /// HI(ICRU-83) = (D2% − D98%) / D50%
    static func homogeneityIndexICRU83(d2: Double, d98: Double, d50: Double) -> Double? {
        guard d50 > 0 else { return nil }
        return finite((d2 - d98) / d50)
    }

    /// R50% = V50%Rx / TV
    static func r50(v50: Double, tv: Double) -> Double? {
        guard v50 > 0, tv > 0 else { return nil }
        return finite(v50 / tv)
    }

    /// GI(Paddick) = V50%Rx / PIV
    static func gradientIndexPaddick(v50: Double, piv: Double) -> Double? {
        guard v50 > 0, piv > 0 else { return nil }
        return finite(v50 / piv)
    }

    /// D2cm を処方線量比 % で表す。
    ///
    /// RTOG 0813 / 0915 の表の見出しは "% of dose prescribed" と "(Gy)" を併記しているが、
    /// 値域（50.0〜94.0）から % が正しい（app/docs/data-sources.md）。
    static func d2cmPercent(d2cmDose: Double, prescriptionDose rx: Double) -> Double? {
        guard d2cmDose >= 0, rx > 0 else { return nil }
        return finite(d2cmDose / rx * 100.0)
    }

    /// 入力の物理的な矛盾を検出する。nil の項目は判定対象外。
    static func issues(
        tv: Double?, piv: Double?, tvPIV: Double?, v50: Double?,
        d2: Double?, d98: Double?, d50: Double?
    ) -> [PlanQualityIssue] {
        var found: [PlanQualityIssue] = []

        if let tvPIV, let tv, tvPIV > tv { found.append(.tvPIVExceedsTV) }
        if let tvPIV, let piv, tvPIV > piv { found.append(.tvPIVExceedsPIV) }
        if let v50, let piv, v50 < piv { found.append(.v50LessThanPIV) }
        if let d2, let d98, d98 > d2 { found.append(.d98ExceedsD2) }
        if let d2, let d98, let d50, d50 > d2 || d50 < d98 { found.append(.d50OutOfRange) }

        return found
    }
}
