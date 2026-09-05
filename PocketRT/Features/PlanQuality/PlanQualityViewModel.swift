import Foundation

@Observable
final class PlanQualityViewModel {

    // 入力（文字列で保持し、Double? に変換する）
    var tvText = ""            // PTV 体積 (cc)
    var rxText = ""            // 処方線量 (Gy)
    var pivText = ""           // 処方等線量体積 (cc)
    var tvPIVText = ""         // PTV 内で処方線量以上の体積 (cc)
    var v50Text = ""           // 50% 等線量体積 (cc)
    var dmaxText = ""          // 最大線量 (Gy)
    var d2Text = ""            // D2% (Gy)
    var d98Text = ""           // D98% (Gy)
    var d50Text = ""           // D50% (Gy)
    var d2cmText = ""          // PTV から 2cm 外側の最大線量 (Gy)
    var fractionsText = ""     // 分割数
    var selectedProtocol: ProtocolSelection = .none

    /// 現在登録されている自施設の基準の一覧。View 側
    /// （`CustomProtocolStoreModel.protocols`）と同期させる（`PlanQualityView`
    /// の `.onAppear` / `.onChange`）。`selectedProtocol` が `.custom(id)` の
    /// とき、判定のたびにここから id で引く。値のコピーを持たないことで、
    /// 選択後に削除・編集されても判定が古い内容のまま出続ける事故を防ぐ。
    var customProtocols: [CustomProtocol] = []

    /// `selectedProtocol` が `.custom(id)` のとき、現在の内容を id で解決する。
    /// 削除されていれば `nil`（「もう無い」）。値のコピーではなく都度この
    /// 配列から引くことで、削除・編集に自動的に追随する。
    private var resolvedCustomProtocol: CustomProtocol? {
        guard case .custom(let id) = selectedProtocol else { return nil }
        return customProtocols.first { $0.id == id }
    }

    /// 判定パネルの見出しに出す、選択中のプロトコルの表示名。
    ///
    /// `ProtocolSelection.displayName` は `.custom` の実名を解決できない
    /// （id しか持たないため）。ここで `customProtocols` から実際の名前を
    /// 引く。削除されていれば「もう無い」ことが利用者に分かる文言にする。
    /// 黙って「判定しない」に戻すと、なぜ判定が消えたのか画面から分からない
    /// （このアプリは「どの経路も黙って終わらない」を原則にしている）。
    var selectedProtocolDisplayName: String {
        switch selectedProtocol {
        case .none, .builtIn:
            selectedProtocol.displayName
        case .custom:
            resolvedCustomProtocol?.name ?? String(localized: "削除された基準")
        }
    }

    // 正の値のみ受け付ける。0・負値・非数値・非有限（inf/nan）は nil
    //
    // Double("1e309") や Double("inf") は +∞ を返し、∞ > 0 は真になるため
    // isFinite の確認が必須。TPS からの DVH 値ペーストで到達しうる。
    private func positive(_ s: String) -> Double? {
        guard let v = Double(s), v.isFinite, v > 0 else { return nil }
        return v
    }

    var tv: Double? { positive(tvText) }
    var rx: Double? { positive(rxText) }
    var piv: Double? { positive(pivText) }
    var tvPIV: Double? { positive(tvPIVText) }
    var v50: Double? { positive(v50Text) }
    var dmax: Double? { positive(dmaxText) }
    var d2: Double? { positive(d2Text) }
    var d98: Double? { positive(d98Text) }
    var d50: Double? { positive(d50Text) }
    var d2cmDose: Double? { positive(d2cmText) }
    var fractions: Int? {
        guard let n = Int(fractionsText), n > 0 else { return nil }
        return n
    }

    func error(for text: String, value: Double?) -> String? {
        guard !text.isEmpty else { return nil }
        return value == nil ? String(localized: "正の数値を入力") : nil
    }

    // 矛盾検出
    var issues: [PlanQualityIssue] {
        PlanQualityIndices.issues(
            tv: tv, piv: piv, tvPIV: tvPIV, v50: v50, d2: d2, d98: d98, d50: d50)
    }

    // 指標。入力が揃わないものは nil
    var ciRTOG: Double? {
        guard let piv, let tv else { return nil }
        return PlanQualityIndices.conformityIndexRTOG(piv: piv, tv: tv)
    }
    var ciPaddick: Double? {
        guard let tvPIV, let tv, let piv else { return nil }
        return PlanQualityIndices.conformityIndexPaddick(tvPIV: tvPIV, tv: tv, piv: piv)
    }
    var hiRTOG: Double? {
        guard let dmax, let rx else { return nil }
        return PlanQualityIndices.homogeneityIndexRTOG(maxDose: dmax, prescriptionDose: rx)
    }
    var hiICRU83: Double? {
        guard let d2, let d98, let d50 else { return nil }
        return PlanQualityIndices.homogeneityIndexICRU83(d2: d2, d98: d98, d50: d50)
    }
    var r50Value: Double? {
        guard let v50, let tv else { return nil }
        return PlanQualityIndices.r50(v50: v50, tv: tv)
    }
    var giPaddick: Double? {
        guard let v50, let piv else { return nil }
        return PlanQualityIndices.gradientIndexPaddick(v50: v50, piv: piv)
    }
    var d2cmValue: Double? {
        guard let d2cmDose, let rx else { return nil }
        return PlanQualityIndices.d2cmPercent(d2cmDose: d2cmDose, prescriptionDose: rx)
    }

    // MARK: - 逸脱判定

    /// 判定を出せない理由の種別。
    ///
    /// 「入力が足りない」と「公表プロトコルがこの計画を扱っていない」は
    /// 臨床的に別のことなので、同じ見え方にしない。
    enum JudgementBlockKind: Sendable {
        /// 入力を足せば解決する
        case incompleteInput
        /// 入力を足しても解決しない。公表プロトコルの適用範囲外
        case outsideProtocolScope
        /// 選択していた自施設の基準が削除された。入力を足しても解決しない
        /// （選び直すしかない）ので `incompleteInput` とは分ける。黙って
        /// `.none` 扱いにすると、なぜ判定が消えたのか利用者から分からない。
        case selectedCustomProtocolDeleted
    }

    /// 判定パネルに出す帰属の文言。
    ///
    /// `.builtIn` の判定は「本判定は公表された表の参照であり…」が成立する
    /// （表が RTOG という外部の公表物だから。仕様 §1.2）。`.custom` の判定は
    /// 利用者が登録した基準によるものであり、公表プロトコルへの適合を示す
    /// ものではない。**判定と帰属は一体で、判定が出るのに帰属が無い状態を
    /// 作ってはならない**（利用者が「基準内」という段階名だけを見ても、
    /// それが誰の基準かが画面から分からなくなる）。
    ///
    /// `selectedProtocol` の 3 ケースにそのまま対応する 1 つのプロパティに
    /// しているのは、2 つの文言が同時に出ないことを型で保証するため
    /// （enum は同時に 2 つの case になれない）。View 側の if/else の
    /// 組み方に依存させると、分岐を書き換えたときに同時表示の事故が
    /// 起こりうる。ここに 1 箇所へ集約し、テストで固定できるようにした。
    enum AttributionNote: Equatable, Sendable {
        /// `.builtIn` — 公表プロトコル（RTOG 0813 / 0915）の判定である旨
        case publishedProtocol
        /// `.custom` — 利用者が登録した基準による判定である旨
        case userDefined
        /// `.none` — 判定そのものが無いので、帰属を出す必要が無い
        case none
    }

    var attributionNote: AttributionNote {
        switch selectedProtocol {
        case .none: .none
        case .builtIn: .publishedProtocol
        case .custom: .userDefined
        }
    }

    /// 頭部定位照射（Shaw 1993）を選んでいるか。
    ///
    /// GI (Paddick) の但し書き・Coverage を判定していない旨・境界の安全側の明示・
    /// 1993 年の文書であることの明示など、頭部定位照射選択時だけ出す UI 要素の
    /// 表示条件として使う唯一の判定点（仕様 §2.5）。**肺 SBRT 選択時・未選択時・
    /// `.custom` では常に false。** 単発病変が前提の肺 SBRT で GI の但し書きが
    /// 常に出るような取り違えを防ぐため、ここに 1 箇所へ集約する
    /// （`View` 側の if/else の組み方に依存させない。`attributionNote` と同じ考え方）。
    var isCranialSRSSelected: Bool {
        if case .builtIn(.cranialSRS) = selectedProtocol { true } else { false }
    }

    /// 肺 SBRT（RTOG 0915 / 0813）を選んでいるか。
    ///
    /// `isCranialSRSSelected` と対になる表示条件の集約点。`ConformityCriteria.scopeNote`
    /// （判定表が線量分割によらないことの説明）は RTOG 0915 / 0813 の表に固有の話で、
    /// 頭部定位照射には線量分割という概念自体が無い（`studiedSchedules` が空配列）ため
    /// 一切当てはまらない。**欠陥修正:** 以前は `View` 側で `selectedProtocol.summary != nil`
    /// という緩い条件を使っており、summary を持つ頭部定位照射にも scopeNote が漏れていた。
    /// `View` の if/else に条件を散らさず、ここに 1 箇所へ集約する（`isCranialSRSSelected`
    /// と同じ考え方）。
    var isLungSBRTSelected: Bool {
        switch selectedProtocol {
        case .builtIn(.rtog0915), .builtIn(.rtog0813): true
        default: false
        }
    }

    /// 判定パネルの「この判定基準について」折りたたみを表示する対象か。
    ///
    /// 頭部定位照射（境界の安全側の扱い・Coverage の詳しい説明）と肺 SBRT
    /// （scopeNote・R50% の定義差）はそれぞれプロトコルの背景・方法論についての
    /// 注記を持つ。折りたたむ判断基準は「いま出ている判定結果の読み方を変えない」
    /// こと（読み方を変えるものは常時表示側に残す。仕様: UI 整理の指摘）。
    /// `.custom` は帰属文言だけで背景注記を持たず（触らない要件）、`.none` は
    /// 判定自体が無いので、どちらも折りたたみを出さない。
    var showsProtocolBackgroundNotes: Bool {
        isCranialSRSSelected || isLungSBRTSelected
    }

    /// 判定が適用できない理由。nil なら適用できる。
    ///
    /// `.builtIn` と `.custom` で判定できる条件が違う。`.custom` の閾値は
    /// PTV 体積に依存しない固定値なので（仕様 §2.1）、`.builtIn` のような
    /// 「PTV 体積が表の範囲内か」「検討された線量分割と一致するか」の検査は
    /// 意味を持たない。そもそもその概念が無い（`studiedSchedules` が常に
    /// nil）。パネル全体を止めるのは、どの指標であっても判定にならない
    /// 明確な理由（プロトコル未選択・入力の矛盾）に限る。個々の指標の
    /// 入力待ち・未設定は行ごとに表す（`PlanQualityView` 側）。
    var judgementBlockedReason: String? {
        switch selectedProtocol {
        case .none:
            return String(localized: "プロトコルが選択されていません")

        case .custom:
            guard resolvedCustomProtocol != nil else {
                // 選択していた基準が削除された。黙って「判定しない」扱いに
                // せず、理由を出す。選び直すしかないので、入力を足しても
                // 解決しない旨が伝わる文言にする。
                return String(localized: "選択していた基準は削除されました。プロトコルを選び直してください")
            }
            if !issues.isEmpty {
                return String(localized: "入力に矛盾があるため判定できません")
            }
            return nil

        case .builtIn(.cranialSRS):
            // Shaw 1993 は特定の線量分割を検討した臨床試験ではなく QA の枠組みで、
            // PTV 体積にも依存しない（仕様 §3.1 / §3.2）。RTOG 0813 / 0915 のような
            // PTV 体積の表範囲・検討された線量分割の一致検査は意味を持たない
            // （`studiedSchedules` が空。`.custom` と同じ扱いになる）。矛盾入力の
            // 有無だけを見る。個々の指標の入力待ちは行ごとに表す。
            if !issues.isEmpty {
                return String(localized: "入力に矛盾があるため判定できません")
            }
            return nil

        case .builtIn(.rtog0915), .builtIn(.rtog0813):
            guard let tv else {
                return String(localized: "PTV 体積が未入力です")
            }
            guard ConformityCriteria.limits(ptvVolume: tv) != nil else {
                let lower = ConformityCriteria.table.first?.ptvVolume ?? 0
                let upper = ConformityCriteria.table.last?.ptvVolume ?? 0
                return String(localized: "PTV 体積が表の範囲（\(lower, specifier: "%.1f")〜\(upper, specifier: "%.1f") cc）外のため判定できません")
            }
            if let schedules = selectedProtocol.studiedSchedules, let n = fractions {
                // 何が一致しないのかを分けて伝える。「一致しません」だけでは、
                // 入力を直せばよいのか、そもそも別のプロトコルを選ぶべきなのかが
                // 判断できない。
                let sameFractions = schedules.filter { $0.fractions == n }
                if sameFractions.isEmpty {
                    let label = selectedProtocol.expectedFractionsLabel ?? ""
                    return String(localized: "このプロトコルが検討したのは \(label) 分割です。入力は \(n) 分割のため判定できません")
                }
                // 分割数は合っている。次に 1 回線量を見る
                if let rx, rx > 0 {
                    let perFraction = rx / Double(n)
                    if !sameFractions.contains(where: { $0.matches(fractions: n, dosePerFraction: perFraction) }) {
                        let studied = sameFractions.map(\.label).formatted(.list(type: .or, width: .narrow))
                        return String(localized: "このプロトコルが \(n) 分割で検討したのは \(studied)です。入力は \(DoseFormat.doseString(rx)) Gy（\(DoseFormat.doseString(perFraction)) Gy/回）のため判定できません")
                    }
                }
            }
            if fractions == nil {
                return String(localized: "分割数が未入力です")
            }
            if !issues.isEmpty {
                return String(localized: "入力に矛盾があるため判定できません")
            }
            return nil
        }
    }

    /// `judgementBlockedReason` の種別。両者はブロックの有無について必ず一致する。
    var judgementBlockKind: JudgementBlockKind? {
        switch selectedProtocol {
        case .none:
            return .incompleteInput

        case .custom:
            guard resolvedCustomProtocol != nil else {
                return .selectedCustomProtocolDeleted
            }
            return issues.isEmpty ? nil : .incompleteInput

        case .builtIn(.cranialSRS):
            // judgementBlockedReason と同じ理由で、PTV 体積の範囲・検討された
            // 線量分割の検査は行わない（`.custom` と同じ扱い）。
            return issues.isEmpty ? nil : .incompleteInput

        case .builtIn(.rtog0915), .builtIn(.rtog0813):
            guard let tv else {
                return .incompleteInput
            }
            guard ConformityCriteria.limits(ptvVolume: tv) != nil else {
                return .outsideProtocolScope
            }
            // 分割数・線量のいずれが外れていても、入力を足しても解決しないので
            // 適用範囲外。判定できない理由の生成と同じ条件で分岐させる。
            if let schedules = selectedProtocol.studiedSchedules, let n = fractions {
                let sameFractions = schedules.filter { $0.fractions == n }
                if sameFractions.isEmpty {
                    return .outsideProtocolScope
                }
                if let rx, rx > 0 {
                    let perFraction = rx / Double(n)
                    if !sameFractions.contains(where: { $0.matches(fractions: n, dosePerFraction: perFraction) }) {
                        return .outsideProtocolScope
                    }
                }
            }
            if fractions == nil {
                return .incompleteInput
            }
            if !issues.isEmpty {
                return .incompleteInput
            }
            return nil
        }
    }

    /// RTOG 0813 / 0915 の表から引いた許容値。この 2 プロトコルのときだけ意味を持つ。
    ///
    /// `ConformityCriteria.limits(ptvVolume:)` は PTV 体積だけから引けて
    /// しまうため、`selectedProtocol` を見ずに呼ぶと `.custom` を選んでいても
    /// 値が返ってしまう（`.custom` の閾値は PTV 体積に依存しないので、
    /// この表とは無関係）。ここで `.builtIn(.rtog0813)` / `.builtIn(.rtog0915)` に
    /// 限定し、`.custom` では常に nil にする。呼び出し側（View の許容値表示）が
    /// RTOG の数値を誤って出さないための唯一の防波堤なので、ここで確実に止める。
    ///
    /// `.builtIn(.cranialSRS)` も PTV 体積の表に依存しないので、ここでは常に
    /// nil を返す（頭部定位照射の許容値は `ConformityCriteria.mdpd*` /
    /// `pitv*` の固定値であり、この表の対象ではない。仕様 §3.2）。
    var limits: ConformityLimits? {
        switch selectedProtocol {
        case .builtIn(.rtog0813), .builtIn(.rtog0915):
            guard judgementBlockedReason == nil, let tv else { return nil }
            return ConformityCriteria.limits(ptvVolume: tv)
        case .builtIn(.cranialSRS), .custom, .none:
            return nil
        }
    }

    /// 選択中のプロトコルが該当指標の閾値を持たない場合 `true`。
    ///
    /// `.builtIn`（RTOG の表は 3 指標すべてを持つ）と `.none` では常に
    /// `false`。`.custom` は施設が定めていない指標を持てる（仕様 §2.2:
    /// 「すべての指標を必須にしない」）。
    ///
    /// 「閾値が無いので判定していない」と「値が未入力で判定していない」は
    /// 別の状態である。どちらも `xxxDeviation` は nil を返すため
    /// （0 や「基準内」にしないという要件上、区別せず nil にまとめている）、
    /// 呼び出し側（View）がこれを見て文言を出し分ける。品質タブで
    /// 「入力待ち」と「範囲外」を混同しないよう別扱いにした経緯、D1 で
    /// 「登録なし」と「読めていない」を分けた経緯と同じ理由。
    func isThresholdUnconfigured(_ key: MetricKey) -> Bool {
        guard let p = resolvedCustomProtocol else { return false }
        return p.thresholds[key] == nil
    }

    /// 選択中の `.custom` プロトコルが定めている閾値を表示用文字列にする。
    ///
    /// `.builtIn` は判定行の下に RTOG の許容値（`limits`）を表示するが、
    /// `.custom` は `limits` が常に nil のため、この表示が無いままだと
    /// 「基準をやや超える」という段階名だけが出て、何と比べた結果なのか
    /// 画面から確認できない。編集画面まで戻らないと閾値を確認できないのは、
    /// 公表プロトコル（出典・対象集団・線量分割を判定と同じ画面で示す）より
    /// 利用者定義の基準のほうが不透明という、権威の弱い側がより不透明になる
    /// 逆転を生む。レビュー指摘により追加。
    ///
    /// 定めている指標だけを拾う（`CustomProtocolEditorView.thresholdSummary`
    /// と同じ考え方。未設定の指標を 0.0 などで埋めない）。`tolerated` がある
    /// 指標は 3 段階判定に両方の閾値が効いているため、`within` だけでなく
    /// 両方を示す。`tolerated` が無い指標（2 段階）は 1 つだけ示す。
    ///
    /// `.builtIn` / `.none` では空文字列を返す。呼び出し側（View）は
    /// 空なら表示行そのものを出さない。
    /// 登録した閾値の要約。
    ///
    /// 段階名（「基準内」「基準をやや超える」）と区切りは、素の `String` に
    /// 書くとカタログに入らず、英語環境で日本語のまま出る。判定そのものは
    /// 訳されているのにこの 1 行だけ日本語という状態になっていた（2026-09-05）。
    var customThresholdSummary: String {
        guard let p = resolvedCustomProtocol else { return "" }
        return MetricKey.allCases.compactMap { key -> String? in
            guard let t = p.thresholds[key] else { return nil }
            let name = key.displayName
            let within = DoseFormat.plainString(t.within)
            var text = String(localized: "\(name) < \(within)（基準内）")
            if let tolerated = t.tolerated {
                let value = DoseFormat.plainString(tolerated)
                text += String(localized: " / < \(value)（基準をやや超える）")
            }
            return text
        }.joined(separator: String(localized: "、", comment: "登録した閾値どうしの区切り"))
    }

    var r50Deviation: DeviationLevel? {
        guard let v = r50Value else { return nil }
        switch selectedProtocol {
        case .builtIn:
            guard let limits else { return nil }
            return ConformityCriteria.judge(value: v, none: limits.r50None, minor: limits.r50Minor)
        case .custom:
            guard judgementBlockedReason == nil, let t = resolvedCustomProtocol?.thresholds[.r50] else { return nil }
            return ConformityCriteria.judge(value: v, upperNone: t.within, upperMinor: t.tolerated)
        case .none:
            return nil
        }
    }

    var d2cmDeviation: DeviationLevel? {
        guard let v = d2cmValue else { return nil }
        switch selectedProtocol {
        case .builtIn:
            guard let limits else { return nil }
            return ConformityCriteria.judge(value: v, none: limits.d2cmNone, minor: limits.d2cmMinor)
        case .custom:
            guard judgementBlockedReason == nil, let t = resolvedCustomProtocol?.thresholds[.d2cm] else { return nil }
            return ConformityCriteria.judge(value: v, upperNone: t.within, upperMinor: t.tolerated)
        case .none:
            return nil
        }
    }

    var r100Deviation: DeviationLevel? {
        guard let v = ciRTOG else { return nil }
        switch selectedProtocol {
        case .builtIn(.rtog0813), .builtIn(.rtog0915):
            guard judgementBlockedReason == nil else { return nil }
            return ConformityCriteria.judge(
                value: v, none: ConformityCriteria.r100None, minor: ConformityCriteria.r100Minor)
        case .builtIn(.cranialSRS):
            // Shaw 1993 は R100%（RTOG 0813 / 0915 固有の許容値 1.2 / 1.5）を
            // 判定基準に持たない。同じ値（`ciRTOG`）を PITV として `pitvDeviation`
            // が別の基準で判定する。ここで誤って RTOG の許容値を当ててはならない。
            return nil
        case .custom:
            guard judgementBlockedReason == nil, let t = resolvedCustomProtocol?.thresholds[.r100] else { return nil }
            return ConformityCriteria.judge(value: v, upperNone: t.within, upperMinor: t.tolerated)
        case .none:
            return nil
        }
    }

    // MARK: - 頭部定位照射（Shaw 1993）の判定

    /// Homogeneity index（MDPD）の判定。`hiRTOG` と同じ値を Shaw 1993 の許容値
    /// （`ConformityCriteria.mdpdUpperNone` / `mdpdUpperMinor`）で判定する。
    /// `.builtIn(.cranialSRS)` のときだけ意味を持つ。他のプロトコルでは常に nil
    /// （原典が MDPD を定めていない。仕様 §2.1 はこの指標に固有の判定である）。
    ///
    /// **`upperNoneIsInclusive: true` を渡す。** 原典は "less than or equal to
    /// 2.0" と明示しており、2.0 ちょうどが per protocol（仕様 §2.3）。
    /// 渡し忘れると 2.0 ちょうどが誤って minor になる
    /// （`ConformityCriteria.mdpdUpperNone` のコメント参照）。
    /// 判定が 1 つでも出ているか。判定カードの見た目（`ResultCard(isDisabled:)`）を
    /// これで決める。
    ///
    /// **プロトコルごとに条件を分けてはならない。** 以前は判定カードだけが
    /// `judgementBlockKind == .incompleteInput` を見ており、肺 SBRT（PTV 体積が
    /// 未入力なら表を引けず判定が止まる）では灰色、頭部定位照射（止まる条件を
    /// 持たず行ごとに「入力待ち」になる）では通常の背景、と同じ「まだ何も
    /// 判定していない」状態が別の見た目になっていた。
    ///
    /// 他タブは `!vm.isValid`（結果が出ていないか）で揃えている。判定パネルも
    /// 同じ意味に揃える。各 `*Deviation` は対象外のプロトコルでは `nil` を返すので、
    /// ここで全部を見れば足りる。
    var hasAnyJudgement: Bool {
        guard judgementBlockedReason == nil else { return false }
        return [r100Deviation, r50Deviation, d2cmDeviation, mdpdDeviation, pitvDeviation]
            .contains { $0 != nil }
    }

    var mdpdDeviation: DeviationLevel? {
        guard case .builtIn(.cranialSRS) = selectedProtocol,
              judgementBlockedReason == nil, let v = hiRTOG else { return nil }
        return ConformityCriteria.judge(
            value: v, upperNone: ConformityCriteria.mdpdUpperNone, upperMinor: ConformityCriteria.mdpdUpperMinor,
            upperNoneIsInclusive: true)
    }

    /// Conformity index（PITV）の判定。`ciRTOG` と同じ値だが、Shaw 1993 は
    /// 両側判定（仕様 §2.2）。`.builtIn(.cranialSRS)` のときだけ意味を持つ。
    /// RTOG 0813 / 0915 の R100%（同じ `ciRTOG` を片側・別の許容値で判定する）
    /// と混同しないこと（`r100Deviation` 参照）。
    var pitvDeviation: DeviationLevel? {
        guard case .builtIn(.cranialSRS) = selectedProtocol,
              judgementBlockedReason == nil, let v = ciRTOG else { return nil }
        return ConformityCriteria.judge(
            value: v,
            upperNone: ConformityCriteria.pitvUpperNone, upperMinor: ConformityCriteria.pitvUpperMinor,
            lowerNone: ConformityCriteria.pitvLowerNone, lowerMinor: ConformityCriteria.pitvLowerMinor)
    }

    /// MDPD の許容値キャプション（判定パネルの表示用）。
    ///
    /// **表示された不等号のとおりに判定される。** `mdpdDeviation` が実際に使う
    /// 境界の包含関係と必ず一致させること。以前は View に文字列リテラルとして
    /// 直接埋め込んでおり、`upperNoneIsInclusive: true`（2.0 を含む＝「以下」）
    /// で判定しているのに表示は「< 2.0」（含まない）と書かれていた。判定結果は
    /// 正しいのに根拠の表示が食い違うと、利用者は正しい判定のほうを疑うことに
    /// なる（レビュー指摘により修正。ここに一元化しテストで固定する）。
    ///
    /// `.builtIn(.cranialSRS)` を選んでいるかどうかに関わらず、常に同じ文字列を
    /// 返す（許容値そのものはプロトコルの選択状態に依存しない定数のため）。
    /// 呼び出し側（View）が `isCranialSRSSelected` を見て表示するかどうかを決める。
    var mdpdLimitsCaption: String {
        String(format: String(localized: "許容値 MDPD: %.1f 以下で none、%.1f 超 %.1f 未満で minor、%.1f 以上で major"),
               ConformityCriteria.mdpdUpperNone,
               ConformityCriteria.mdpdUpperNone, ConformityCriteria.mdpdUpperMinor,
               ConformityCriteria.mdpdUpperMinor)
    }

    /// PITV の許容値キャプション（判定パネルの表示用）。`mdpdLimitsCaption` と同じ理由。
    ///
    /// 「1.0〜2.0 (none) / 0.9〜2.5 (minor)」のような範囲表記は、境界を含むかどうかが
    /// 読み取れない（下限は含み上限は含まない非対称な規約のため。
    /// `ConformityCriteria.judge` のドキュメント参照）。none/minor/major の 3 段階を
    /// 不等号つきで書き下し、読み取りの余地を無くす。
    var pitvLimitsCaption: String {
        String(format: String(localized: "許容値 PITV: %.1f 以上 %.1f 未満で none、%.1f 超 %.1f 未満または %.1f 以上 %.1f 未満で minor、%.1f 以下または %.1f 以上で major"),
               ConformityCriteria.pitvLowerNone, ConformityCriteria.pitvUpperNone,
               ConformityCriteria.pitvLowerMinor, ConformityCriteria.pitvLowerNone,
               ConformityCriteria.pitvUpperNone, ConformityCriteria.pitvUpperMinor,
               ConformityCriteria.pitvLowerMinor, ConformityCriteria.pitvUpperMinor)
    }
}
