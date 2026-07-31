import Foundation

enum OARConversionMode: Hashable {
    case fractions
    case dosePerFraction
}

@Observable
final class OARConversionViewModel {
    var sourceDoseText: String = "50"
    var sourceFractionsText: String = "25"
    var alphaBetaText: String = "3"
    var mode: OARConversionMode = .fractions
    var targetFractionsText: String = "10"
    var targetDoseFxText: String = "3.0"

    var sourceDose: Double? { Double(sourceDoseText) }
    var sourceFractions: Int? { Int(sourceFractionsText) }
    var alphaBeta: Double? { Double(alphaBetaText) }
    var targetFractions: Int? { Int(targetFractionsText) }
    var targetDoseFx: Double? { Double(targetDoseFxText) }

    var sourceDoseError: String? {
        guard let v = sourceDose else { return sourceDoseText.isEmpty ? nil : "数値を入力" }
        return (0.1...200).contains(v) ? nil : "0.1〜200 Gy"
    }
    var sourceFractionsError: String? {
        guard let v = sourceFractions else { return sourceFractionsText.isEmpty ? nil : "整数を入力" }
        return (1...99).contains(v) ? nil : "1〜99 Fr"
    }
    var alphaBetaError: String? {
        guard let v = alphaBeta else { return alphaBetaText.isEmpty ? nil : "数値を入力" }
        return (0.5...30).contains(v) ? nil : "0.5〜30 Gy"
    }

    var targetError: String? {
        switch mode {
        case .fractions:
            guard let v = targetFractions else { return targetFractionsText.isEmpty ? nil : "整数を入力" }
            return (1...99).contains(v) ? nil : "1〜99 Fr"
        case .dosePerFraction:
            guard let v = targetDoseFx else { return targetDoseFxText.isEmpty ? nil : "数値を入力" }
            return (0.1...30).contains(v) ? nil : "0.1〜30 Gy"
        }
    }

    var isValid: Bool {
        sourceDoseError == nil && sourceFractionsError == nil
            && alphaBetaError == nil && targetError == nil
    }

    var result: ConversionResult? {
        guard isValid,
              let D = sourceDose, let n = sourceFractions, let ab = alphaBeta else { return nil }
        let target: ConversionTarget = switch mode {
        case .fractions: .fractions(targetFractions ?? 0)
        case .dosePerFraction: .dosePerFraction(targetDoseFx ?? 0)
        }
        return LQCore.convertConstraint(
            sourceDose: D, sourceFractions: n, alphaBeta: ab, target: target
        )
    }
}
