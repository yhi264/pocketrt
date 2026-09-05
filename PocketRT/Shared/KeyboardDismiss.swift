import SwiftUI
import UIKit

/// 数値入力を持つ画面に、キーボードを閉じる手段を与える。
///
/// `.keyboardType(.decimalPad)` にはリターンキーが無い。SwiftUI は既定で
/// 「画面の余白を叩いたら閉じる」動作も持たない。何も足さないと、入力欄を
/// 一度叩いた利用者はキーボードを閉じられず、**キーボードが覆っているタブバーに
/// 触れないためタブの切り替えもできなくなる**（2026-08-19 に UI テストで検出。
/// build 5 まで届いていた）。
///
/// 手段を 2 つ用意する。
///
/// - **「完了」ボタン**（キーボード上のツールバー）。確実に押せる導線で、
///   どの画面でも同じ位置に出る
/// - **スクロールによる却下**。iOS で人が自然に試す操作。ボタンを探さずに済む
///
/// 片方だけでは足りない。ツールバーだけだと、スクロールしても閉じないことに
/// 利用者が戸惑う。スクロールだけだと、内容が短くスクロールできない画面で
/// 閉じる手段が無くなる。
///
/// - Note: `ToolbarItemGroup(placement: .keyboard)` はキーボードが出ている間
///   だけ表示される。個々の `NumberField` ではなく画面（`ScrollView` / `Form`）に
///   一度だけ付けること。入力欄ごとに付けると同じツールバーが重複して積まれる。
struct DismissibleKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { Self.resignFirstResponder() }
                }
            }
    }

    /// `@FocusState` を使わないのは、それが**入力欄そのもの**に
    /// `.focused($state)` を付けて初めて働くためである。画面（`ScrollView`）に
    /// 付けても束ねられず、`isFocused = false` は何も起こさない。
    /// 束ねるには `NumberField` に `FocusState.Binding` と識別子を通す必要があり、
    /// 5 画面 24 欄すべての呼び出しを書き換えることになる。
    ///
    /// ここでやりたいのは「いま第一応答者になっているものを降ろす」ことだけで、
    /// どの欄かを知る必要はない。UIKit に直接頼む方が、通す情報が少なく済む。
    private static func resignFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// 数値入力を持つ画面に付ける。`ScrollView` / `Form` に一度だけ。
    func dismissibleKeyboard() -> some View {
        modifier(DismissibleKeyboard())
    }
}
