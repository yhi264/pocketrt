import SwiftUI

/// 「Gy₁₀」のような α/β 添字つき単位表示
struct GySubscript: View {
    let value: Double
    let alphaBeta: Double?
    let precision: Int

    init(value: Double, alphaBeta: Double? = nil, precision: Int = 1) {
        self.value = value
        self.alphaBeta = alphaBeta
        self.precision = precision
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%.\(precision)f", value))
                .font(.title3.monospacedDigit())
            Text("Gy")
                .font(.body)
            if let ab = alphaBeta {
                let abStr = ab == ab.rounded() ? "\(Int(ab))" : String(format: "%.1f", ab)
                Text(abStr)
                    .font(.caption2)
                    .baselineOffset(-4)
            }
        }
    }
}
