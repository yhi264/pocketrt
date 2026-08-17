import Foundation

/// 線量・α/β の表示用整形。
///
/// 整数に見える値は整数表記、それ以外は小数表記にする（線量は第 2 位、
/// α/β は第 1 位まで）。この書式を作る処理が、内蔵プリセットの
/// `regimenLabel`、自施設プリセットの `regimenLabel`、3 つの ViewModel の
/// `apply()`、`CourseInput.init`、`PresetFormView.load()`、
/// `GySubscript` に独立に実装されていたことが、範囲外の値（例: `1e100`）
/// での `Int()` 変換クラッシュを見落とす一因になった。ここに寄せることで、
/// 書式を直す箇所を 1 つにする。素の `Int(Double)` はアプリ内から使わない。
enum DoseFormat {
    /// 整数に見える値は整数表記、それ以外は指定した桁数の小数表記にする。
    ///
    /// `Int(exactly:)` を使い、変換できない場合（範囲外の巨大な値など）は
    /// 小数表記にフォールバックする。素の `Int(value)` は変換できない値
    /// （例: `1e100`）で実行時にトラップするため使わない。
    private static func string(_ value: Double, decimalPlaces: Int) -> String {
        if value == value.rounded(), let i = Int(exactly: value) {
            return "\(i)"
        }
        return String(format: "%.\(decimalPlaces)f", value)
    }

    /// `totalDose` を表示用文字列にする（小数第 2 位まで）。
    static func doseString(_ totalDose: Double) -> String {
        string(totalDose, decimalPlaces: 2)
    }

    /// `alphaBeta` を表示用文字列にする（小数第 1 位まで）。
    /// 線量とは桁数が違う（線量は第 2 位、α/β は第 1 位）ため、
    /// 桁数を分けて呼び分ける。
    static func alphaBetaString(_ alphaBeta: Double) -> String {
        string(alphaBeta, decimalPlaces: 1)
    }

    /// 値をそのまま表示用文字列にする。整数に見える値は整数表記、そうでなければ
    /// `Double` の既定の文字列表現を使う（桁数を固定しない）。
    ///
    /// `doseString` / `alphaBetaString` と違い、決まった小数点以下の桁数を
    /// 前提にできない値（例: 検証エラーメッセージに出す許容範囲の上下限）に使う。
    /// `Int(exactly:)` を使い、変換できない場合は小数表記にフォールバックする
    /// （素の `Int(Double)` は使わない。理由は本ファイル冒頭のコメントを参照）。
    static func plainString(_ value: Double) -> String {
        if value == value.rounded(), let i = Int(exactly: value) {
            return "\(i)"
        }
        return String(value)
    }

    /// 表示用: "60 Gy / 20 Fr"
    static func regimenLabel(totalDose: Double, fractions: Int) -> String {
        "\(doseString(totalDose)) Gy / \(fractions) Fr"
    }
}
