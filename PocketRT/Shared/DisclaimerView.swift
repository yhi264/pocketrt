import SwiftUI

/// 免責事項の本文のみ。初回同意画面と情報画面の両方から使う。
struct DisclaimerBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本アプリは放射線治療領域の生物学的等価線量(BED/EQD2)などの計算を補助する**教育・参考目的**のツールです。")
            Text("計算結果は臨床判断を直接行うものではなく、最終的な治療方針は必ず以下によって決定してください：")
            VStack(alignment: .leading, spacing: 6) {
                Text("• 施設のプロトコル")
                Text("• 最新のガイドライン（JASTRO, NCCN, ESTRO 等）")
                Text("• 担当医師・物理士の判断")
            }
            .padding(.leading, 8)
            Text("収録された線量分割プリセットは代表例の参考表示であり、最新エビデンス・施設プロトコルとの照合を行ってください。")
            Text("本アプリの使用により生じたいかなる結果についても、開発者は責任を負いません。")
        }
        .font(.body)
    }
}

struct DisclaimerView: View {
    @Binding var hasAccepted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ご利用にあたって")
                .font(.title2.bold())

            ScrollView { DisclaimerBody() }

            Button {
                hasAccepted = true
            } label: {
                Text("同意して開始")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
