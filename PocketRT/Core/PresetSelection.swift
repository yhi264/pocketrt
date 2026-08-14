import Foundation

/// プリセットの選択結果。内蔵と自施設のどちらから来たかを保つ。
///
/// 適用処理を一本化するために包んでいる。由来を落として値だけを渡すと、
/// 出典の帰属を正しく判定できなくなる。
enum PresetSelection: Identifiable, Sendable {
    case builtIn(FractionationPreset)
    case institutional(InstitutionalPreset)

    var id: String {
        switch self {
        case .builtIn(let p): "builtin_\(p.id)"
        case .institutional(let p): "institutional_\(p.id)"
        }
    }

    var totalDose: Double {
        switch self {
        case .builtIn(let p): p.totalDose
        case .institutional(let p): p.totalDose
        }
    }

    var fractions: Int {
        switch self {
        case .builtIn(let p): p.fractions
        case .institutional(let p): p.fractions
        }
    }

    /// nil のときは α/β を変更しない。内蔵は必ず値を持つ。
    var alphaBeta: Double? {
        switch self {
        case .builtIn(let p): p.recommendedAlphaBeta
        case .institutional(let p): p.alphaBeta
        }
    }

    /// 内蔵プリセットの出典。自施設プリセットは出典を持ちえない。
    var citations: [Citation] {
        switch self {
        case .builtIn(let p): p.citations
        case .institutional: []
        }
    }

    /// 自施設プリセットの名前。内蔵は nil。
    var institutionalName: String? {
        switch self {
        case .builtIn: nil
        case .institutional(let p): p.name
        }
    }
}
