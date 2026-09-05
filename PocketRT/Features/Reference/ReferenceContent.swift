import Foundation

/// 解説 1 セクション。
///
/// `title`・`body`・`formula` は `LocalizedStringResource` で保持する。
/// 素の `String` だと String Catalog に抽出されない。
/// `id` は言語非依存の安定キーなので `String` のまま。
///
/// `formula` は当初「数式だから言語に依らない」として `String` にしていたが、
/// 線量勾配の D2cm だけは式の中に日本語の語（「PTV から 2 cm 外側の最大線量」）が
/// 入っており、英語環境で日本語のまま出ていた（2026-09-05）。
struct ReferenceSection: Identifiable {
    let id: String
    let title: LocalizedStringResource
    /// 数式（等幅で表示する）
    let formula: LocalizedStringResource?
    let body: LocalizedStringResource
}

enum ReferenceContent {
    static let sections: [ReferenceSection] = [
        ReferenceSection(
            id: "bed", title: "BED（生物学的等価線量）",
            formula: "BED = n · d · (1 + d / (α/β))",
            body: """
            n は分割回数、d は 1 回線量（= 総線量 ÷ n）、α/β は組織固有のパラメータです。
            Linear-Quadratic モデルに基づき、分割の違いを揃えて比較するための指標です。
            """),

        ReferenceSection(
            id: "eqd2", title: "EQD2（2 Gy 等価線量）",
            formula: "EQD2 = BED / (1 + 2 / (α/β))",
            body: """
            BED を「1 回 2 Gy の通常分割で照射した場合の総線量」に換算した値です。
            臨床で慣用される線量感覚に近いため、BED より解釈しやすい場面があります。
            """),

        ReferenceSection(
            id: "fractionation_conversion", title: "線量分割換算",
            formula: "d' = (α/β)/2 · [ -1 + √(1 + 4·BED / (n'·(α/β))) ]",
            body: """
            元の制約（総線量と分割数）から BED を求め、それと等しい BED になる別の分割を逆算します。
            分割数を指定した場合は上式で 1 回線量 d' を解きます。
            1 回線量を指定した場合は n' = BED / (d'·(1 + d'/(α/β))) を計算し、整数に丸めます。
            この丸めにより、1 回線量を指定したときの結果は元の BED と厳密には一致しません。
            表示される BED は、丸めた分割数で再計算した値です。
            """),

        ReferenceSection(
            id: "alphabeta", title: "α/β 値について",
            formula: nil,
            body: """
            本アプリが収録する α/β は代表的な参考値です。同じ組織でも文献によって報告値は一致しません。
            施設のプロトコルと照合してください。

            腫瘍（一般）10 Gy / 前立腺癌 1.5 Gy / 乳癌 4 Gy /
            晩期反応組織（一般）3 Gy / 脊髄 2 Gy / 脳幹 2 Gy /
            皮膚（急性）10 Gy / 皮膚（晩期）3 Gy
            """),

        ReferenceSection(
            id: "ci", title: "適合性指数（CI）",
            formula: "CI(RTOG) = PIV / TV\nCI(Paddick) = TV_PIV² / (TV × PIV)",
            body: """
            TV は標的体積（PTV）、PIV は処方線量以上を受ける全体積、
            TV_PIV は PTV のうち処方線量以上を受ける体積です。
            RTOG 型は標的外への広がりを区別できませんが、Paddick 型は
            標的の被覆不足と標的外への漏れの両方を反映します。
            """),

        ReferenceSection(
            id: "hi", title: "均一性指数（HI）",
            formula: "HI(RTOG) = Dmax / Rx\nHI(ICRU-83) = (D2% − D98%) / D50%",
            body: """
            Rx は処方線量、Dmax は最大線量、Dx% は標的の x% が受ける線量です。
            どちらも値が小さいほど均一で、RTOG 型は 1、ICRU-83 型は 0 が下限です。
            SBRT では意図的に標的内を不均一にするため、値が大きいことが
            ただちに問題を意味するわけではありません。
            """),

        ReferenceSection(
            id: "falloff", title: "線量勾配（R50%、D2cm、GI）",
            formula: "R50% = V50%Rx / TV\nGI(Paddick) = V50%Rx / PIV\nD2cm = (PTV から 2 cm 外側の最大線量) / Rx × 100",
            body: """
            V50%Rx は処方線量の 50% 以上を受ける体積です。
            いずれも標的の外側で線量がどれだけ速く落ちるかを表し、
            値が小さいほど勾配が急です。

            R50% と D2cm は RTOG 0813 / 0915 が PTV 体積ごとの許容値を定めています。
            本アプリの逸脱判定はその表を参照するもので、推奨や指示ではありません。
            """),

        ReferenceSection(
            id: "limits", title: "本アプリが扱わないこと",
            formula: nil,
            body: """
            ・LQ モデルは 1 回線量が大きい領域（SBRT / SRS）での妥当性が議論されています。
              高線量域では、計算値を確定的なものとして扱わないでください。

            ・治療期間（OTT）の延長に対する生物学的補正は実装していません。
              計画的に治療期間を短縮すると転帰が改善することは、ランダム化試験で支持されています。
              一方、予期せぬ中断による延長の影響はこれとは別の問いで、根拠は観察研究にとどまります。
              その影響量を係数で定量できるかはさらに不確かで、補正によって転帰を回収できることを
              示す臨床エビデンスは確認できませんでした。
              中断が生じた場合は、施設のプロトコルと成書に従ってください。

            ・分割内の中断（照射中の数十分の中断）は亜致死損傷回復の問題であり、
              治療期間の問題とは別のモデルです。本アプリは扱いません。
            """)
    ]
}
