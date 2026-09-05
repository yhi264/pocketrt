import SwiftUI

/// 数値入力 + 単位ラベル + バリデーション赤字
///
/// 行の構成は文字サイズで切り替える。
///
/// - **通常の文字サイズ**: ラベルを左端、入力欄と単位を右端に置く。入力欄に
///   固定幅を与えることで、欄の左端と右端が全行で揃う
/// - **アクセシビリティ用の文字サイズ**: ラベルを上、入力欄を下に積む。
///   横に並べたままだと行が画面幅を超え、ラベルが切れる（実測）
///
/// この切り替えを省くと、どちらかが必ず壊れる。2026-08-04 のデザイン監査は
/// 固定幅ラベルが拡大時に切れることを指摘し（`7e67240` で撤去）、その撤去に
/// よって今度は欄の左端がばらついた。幅を決めるか決めないかの二択で考えている
/// 限り、片方を直すともう片方が壊れる。
struct NumberField: View {
    let label: LocalizedStringKey
    let unit: LocalizedStringKey
    @Binding var value: String
    let error: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 入力欄の幅。**可変にしない。**
    ///
    /// 幅を決めずに置くと、入力欄が行の余白をすべて吸って画面幅いっぱいに
    /// 広がる。ここに入るのは 2〜4 桁の数値（線量 0.1〜200、体積 1.8〜163.0）で、
    /// その桁数に対して広すぎる欄は、入力できる量を過大に見せる。
    ///
    /// 幅を決めると右端も揃う。可変幅では、単位（cc / Gy / Fr）の文字幅の
    /// 違いがそのまま入力欄の右端のずれになっていた。
    ///
    /// 88 は「163.0」「1.200」が余裕をもって収まる幅。
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 88

    /// 単位欄の下限幅。単位は 2 文字（cc / Gy / Fr）だが、下限を与えておくと、
    /// 将来 3 文字の単位を足したときに行の構成が崩れない。
    @ScaledMetric(relativeTo: .body) private var unitMinWidth: CGFloat = 26

    init(label: LocalizedStringKey, unit: LocalizedStringKey, value: Binding<String>, error: String? = nil) {
        self.label = label
        self.unit = unit
        self._value = value
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                stackedLayout
            } else {
                inlineLayout
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// 通常の文字サイズ。ラベルを左端、入力欄と単位を右端に置く。
    ///
    /// 間を `Spacer` で開ける。ラベルは行の左端から始まり、入力欄は行の右端に
    /// 揃う。iOS の設定アプリと同じ構成で、両側の余白が均等に使われる。
    ///
    /// 欄の左端・右端が全行で揃うのは、**入力欄の幅と単位欄の下限幅が固定**で、
    /// 右端から数えた位置が行によらないため。ラベルの長さは揃いに影響しない
    /// ——ラベル欄に下限幅を与えて左から揃える方式では、下限に収まらない
    /// ラベルが 1 つでも増えるとその行だけ崩れたが、右端を基準にすれば
    /// その心配がない。
    private var inlineLayout: some View {
        HStack(spacing: 8) {
            Text(label)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            field
                .frame(width: fieldWidth)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(minWidth: unitMinWidth, alignment: .leading)
        }
    }

    /// アクセシビリティ用の文字サイズ。ラベルを上に置き、入力欄を広く取る。
    ///
    /// ここでは入力欄の幅を決めない。1 行を丸ごと使えるので、桁数に対して
    /// 広すぎるという問題が起きず、逆に幅を固定すると拡大した文字が収まらない。
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                field
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var field: some View {
        TextField("", text: $value)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(Text(label))
            .accessibilityHint(error ?? "")
    }
}
