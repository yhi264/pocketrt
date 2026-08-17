import SwiftUI

/// プライバシーポリシー本文。docs/privacy-policy.md の文言をそのまま収録する
/// （運用メモなど利用者向けでない節は除く）。アプリはネットワーク通信を行わないため、
/// ポリシー自体もアプリ内で完結して読めるようにしている。
struct PrivacyPolicyBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PocketRT プライバシーポリシー")
                .font(.title3.bold())

            section(title: "収集する情報") {
                Text("PocketRT は、利用者の個人情報を一切収集しません。")
                Text("本アプリに入力された線量、分割回数、治療開始日などの情報は、すべて利用者の端末内でのみ処理されます。開発者を含むいかなる第三者にも送信されることはありません。")
            }

            section(title: "ネットワーク通信") {
                Text("本アプリはネットワーク通信を行いません。すべての計算は端末内で完結します。")
            }

            section(title: "第三者への提供") {
                Text("収集する情報が存在しないため、第三者への提供は行いません。解析ツール、広告 SDK、クラッシュレポート収集ツールのいずれも組み込んでいません。")
            }

            section(title: "本アプリの位置づけ") {
                Text("PocketRT は、放射線治療に従事する医療従事者向けの教育および参考用ツールです。診断または治療の判断を行うものではありません。")
                Text("臨床上の判断は、各施設のプロトコルおよび担当医の責任において行われる必要があります。")
            }

            section(title: "お問い合わせ") {
                Text("本ポリシーに関するお問い合わせは、App Store Connect に登録された開発者連絡先までお願いします。")
            }
        }
        .font(.body)
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PrivacyPolicyBody()
                    .padding()

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("公開されている原本はこちら:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // 原本は /privacy/ に置いてある（2026-08-17 に移設）。
                    // ルートは紹介ページで、App Store のマーケティング URL に使う。
                    Link("https://yhi264.github.io/pocketrt/privacy/",
                         destination: URL(string: "https://yhi264.github.io/pocketrt/privacy/")!)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
