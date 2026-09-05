import SwiftUI

struct PlanQualityView: View {
    @State private var vm = PlanQualityViewModel()
    @Environment(CustomProtocolStoreModel.self) private var customProtocolStore
    @State private var showCustomProtocolEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("標的と処方").font(.headline)
                        NumberField(label: "PTV 体積", unit: "cc", value: $vm.tvText,
                                    error: vm.error(for: vm.tvText, value: vm.tv))
                        NumberField(label: "処方線量", unit: "Gy", value: $vm.rxText,
                                    error: vm.error(for: vm.rxText, value: vm.rx))
                        NumberField(label: "分割数", unit: "Fr", value: $vm.fractionsText,
                                    error: vm.fractionsText.isEmpty || vm.fractions != nil ? nil : String(localized: "正の整数を入力"))
                    }

                    Divider()

                    Group {
                        Text("等線量体積").font(.headline)
                        NumberField(label: "PIV", unit: "cc", value: $vm.pivText,
                                    error: vm.error(for: vm.pivText, value: vm.piv))
                        NumberField(label: "PTV∩PIV", unit: "cc", value: $vm.tvPIVText,
                                    error: vm.error(for: vm.tvPIVText, value: vm.tvPIV))
                        NumberField(label: "V50%", unit: "cc", value: $vm.v50Text,
                                    error: vm.error(for: vm.v50Text, value: vm.v50))
                        Text("PIV は処方線量以上を受ける全体積、PTV∩PIV は PTV のうち処方線量以上を受ける体積、V50% は処方線量の 50% 以上を受ける体積。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Group {
                        Text("線量統計").font(.headline)
                        NumberField(label: "Dmax", unit: "Gy", value: $vm.dmaxText,
                                    error: vm.error(for: vm.dmaxText, value: vm.dmax))
                        NumberField(label: "D2%", unit: "Gy", value: $vm.d2Text,
                                    error: vm.error(for: vm.d2Text, value: vm.d2))
                        NumberField(label: "D50%", unit: "Gy", value: $vm.d50Text,
                                    error: vm.error(for: vm.d50Text, value: vm.d50))
                        NumberField(label: "D98%", unit: "Gy", value: $vm.d98Text,
                                    error: vm.error(for: vm.d98Text, value: vm.d98))
                        NumberField(label: "D2cm", unit: "Gy", value: $vm.d2cmText,
                                    error: vm.error(for: vm.d2cmText, value: vm.d2cmDose))
                    }

                    if !vm.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.issues, id: \.rawValue) { issue in
                                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }

                    ResultCard(title: "指標") {
                        VStack(alignment: .leading, spacing: 6) {
                            indexRow("CI (RTOG)", vm.ciRTOG, format: "%.3f")
                            indexRow("CI (Paddick)", vm.ciPaddick, format: "%.3f")
                            indexRow("HI (RTOG)", vm.hiRTOG, format: "%.3f")
                            indexRow("HI (ICRU-83)", vm.hiICRU83, format: "%.3f")
                            indexRow("R50%", vm.r50Value, format: "%.2f")
                            indexRow("GI (Paddick)", vm.giPaddick, format: "%.2f")
                            // 頭部定位照射を選んでいる間だけ添える（仕様 §2.5）。多発脳転移
                            // では GI が意味をなさないことがある（TROG SRS Technical Working
                            // Group §3.3.7）。肺 SBRT 選択時・未選択時には出さない
                            // （単発病変では不要な文言が常に出ることになるため）。
                            if vm.isCranialSRSSelected {
                                Text(ConformityCriteria.giCaveatNote)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            indexRow("D2cm", vm.d2cmValue, format: "%.1f", suffix: " %Rx")
                        }
                    }

                    Divider()

                    Group {
                        Text("プロトコル").font(.headline)
                        // Picker(.menu) ではなく Menu を使う。Picker は畳んだときの
                        // 表示が選択行のラベルそのものになるため、行に線量分割まで
                        // 併記すると畳んだ側が長くなって切れる。Menu なら畳んだ表示と
                        // 行の表示を別々に指定できる。
                        Menu {
                            protocolButton(.none, label: ProtocolSelection.none.displayName)

                            // 自施設の基準を先に、内蔵を後に置く（D1 の PresetSheet と同じ順）。
                            // まだ登録が無い間はセクションごと出さない。空のセクション見出しは
                            // 「登録できる場所がある」というノイズにしかならない。
                            //
                            // .custom(p.id) には名前が無い（値のコピーではなく id を持つ設計。
                            // 削除・編集への追随のため）。ここでは実物の p.name を label に
                            // 直接渡す。ProtocolSelection.menuLabel には解決させない。
                            if !customProtocolStore.protocols.isEmpty {
                                Section("自施設の基準") {
                                    ForEach(customProtocolStore.protocols) { p in
                                        protocolButton(.custom(p.id), label: p.name)
                                    }
                                }
                            }

                            Section("内蔵") {
                                ForEach(BuiltInProtocol.allCases) { p in
                                    protocolButton(.builtIn(p), label: p.menuLabel)
                                }
                            }

                            Button {
                                showCustomProtocolEditor = true
                            } label: {
                                Label("自施設の基準を管理…", systemImage: "square.and.pencil")
                            }
                        } label: {
                            HStack {
                                Text(vm.selectedProtocolDisplayName)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("プロトコル")
                        .accessibilityValue(vm.selectedProtocolDisplayName)
                        .sheet(isPresented: $showCustomProtocolEditor) {
                            CustomProtocolEditorView(model: customProtocolStore)
                        }
                        // customProtocolStore.protocols（削除・編集の唯一の発生源）と
                        // vm.customProtocols を同期させる。selectedProtocol が
                        // .custom(id) を持つとき、判定のたびにここから id で引く。
                        // 値のコピーを vm 側に持たせないことで、削除・編集後も判定が
                        // 古い内容のまま出続ける事故を防ぐ（外部レビューで検出）。
                        .onAppear { vm.customProtocols = customProtocolStore.protocols }
                        .onChange(of: customProtocolStore.protocols) { _, newValue in
                            vm.customProtocols = newValue
                        }

                        // 名前と分割数だけでは、その表が自分の症例に当てはまるかを
                        // 判断できない。何を調べた試験なのかをここで示し、
                        // 書誌情報は出典一覧（情報画面）で確認できるようにする。
                        if let summary = vm.selectedProtocol.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // scopeNote（表が線量分割によらないことの説明）は肺 SBRT
                            // 専用で、かつ「いま出ている判定結果の読み方を変えない」
                            // 背景説明のため、判定パネルの折りたたみ側に移した
                            // （`vm.isLungSBRTSelected` で表示条件を集約。以前はここで
                            // summary != nil という条件だけで出しており頭部定位照射に
                            // 漏れていた欠陥があった）。
                            ForEach(vm.selectedProtocol.citations) { c in
                                HStack(spacing: 6) {
                                    Text(c.formattedReference)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    if let url = c.url {
                                        Link("開く", destination: url).font(.caption2)
                                    }
                                }
                            }
                        }
                    }

                    // 判定が 1 つでも出ているかで見た目を決める。プロトコルごとに
                    // 条件を分けると、同じ「まだ何も判定していない」状態が別の
                    // 見た目になる（vm.hasAnyJudgement のコメント参照）。
                    ResultCard(title: "判定", isDisabled: !vm.hasAnyJudgement) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let reason = vm.judgementBlockedReason {
                                if vm.judgementBlockKind == .outsideProtocolScope {
                                    Label(reason, systemImage: "exclamationmark.circle")
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text(reason)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            } else if vm.isCranialSRSSelected {
                                // 頭部定位照射（Shaw 1993）は R100% / R50% / D2cm ではなく
                                // MDPD（Homogeneity index）と PITV（Conformity index）を判定する
                                // （data-sources.md §B6）。RTOG 0813 / 0915 の行とは指標そのものが
                                // 違うので、同じ行を使い回さない。
                                deviationRow("MDPD (= HI RTOG)", vm.mdpdDeviation)
                                deviationRow("PITV (= CI RTOG)", vm.pitvDeviation)
                                // キャプションの組み立ては ViewModel 側（`mdpdLimitsCaption` /
                                // `pitvLimitsCaption`）に一元化してある。View に文字列リテラルを
                                // 直接書くと、判定の境界（`upperNoneIsInclusive` 等）を変えても
                                // キャプションが追随せず、不等号が判定と食い違う欠陥を生む
                                // （レビューで実際に発生した。PlanQualityViewModelTests で固定）。
                                Text(vm.mdpdLimitsCaption)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(vm.pitvLimitsCaption)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else {
                                // .custom では段階名を customDisplayName（基準内/基準をやや超える/
                                // 基準を超える）に切り替える。「Per protocol」は RTOG のプロトコル
                                // 遵守を指す語で、利用者が自分で登録した基準に出すのは語の誤用になる
                                // （仕様 §3.1）。
                                let isCustom: Bool = { if case .custom = vm.selectedProtocol { true } else { false } }()
                                deviationRow("R100% (= CI RTOG)", vm.r100Deviation,
                                             unconfigured: vm.isThresholdUnconfigured(.r100), useCustomNaming: isCustom)
                                deviationRow("R50%", vm.r50Deviation,
                                             unconfigured: vm.isThresholdUnconfigured(.r50), useCustomNaming: isCustom)
                                deviationRow("D2cm", vm.d2cmDeviation,
                                             unconfigured: vm.isThresholdUnconfigured(.d2cm), useCustomNaming: isCustom)
                                if let l = vm.limits {
                                    Text(String(format: String(localized: "許容値: R50%% < %.2f (none) / < %.2f (minor)、D2cm < %.1f%% / < %.1f%%"),
                                                l.r50None, l.r50Minor, l.d2cmNone, l.d2cmMinor))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                // .builtIn の許容値表示（上）に対応。.custom は limits が
                                // 常に nil なので、この行が無いと「基準をやや超える」という
                                // 段階名だけが出て、何と比べた結果か画面から確認できない
                                // （編集画面まで戻る必要がある）。権威の弱い側（利用者が自分で
                                // 入れた基準）のほうが公表プロトコルより不透明になる逆転を防ぐ。
                                // レビュー指摘により追加。
                                if !vm.customThresholdSummary.isEmpty {
                                    Text("登録した閾値: \(vm.customThresholdSummary)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            // 判定と帰属は一体（仕様 §1.2）。判定が出るのに帰属が無い状態を
                            // 作らない。vm.attributionNote が selectedProtocol の 3 ケースに
                            // 排他的に対応するので、2 つの文言が同時に出ることはない
                            // （型で保証。PlanQualityViewModelTests で固定）。
                            switch vm.attributionNote {
                            case .publishedProtocol where vm.isCranialSRSSelected:
                                // RTOG 0813 / 0915（下の case）と違い、PTV 体積の表・線形補間の
                                // 概念が無い（仕様 §3.2）。出典も Shaw 1993 であり混同しない。
                                Text("出典: \(ConformityCriteria.cranialSourceLabel)。本判定は公表された基準の参照であり、推奨や指示ではありません。")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            case .publishedProtocol:
                                Text("出典: \(ConformityCriteria.sourceLabel)。表にない PTV 体積は原典 Note 1 に従い線形補間しています。本判定は公表された表の参照であり、推奨や指示ではありません。")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            case .userDefined:
                                // 常時表示。折りたたまない（仕様 §3.3）。「Per protocol」同様、
                                // ここでも公表プロトコルへの適合という誤解を避ける文言にする。
                                Text("この判定は利用者が登録した基準によるものです。公表されたプロトコルへの適合を示すものではありません。")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            case .none:
                                EmptyView()
                            }
                            // 頭部定位照射固有の明示（仕様 §2.3 / §2.4）。attributionNote と
                            // 同じく常時表示し、折りたたまない。判定がブロックされていても
                            // 「原典は 3 基準を定めるが本アプリは 2 つしか判定しない」という
                            // 事実そのものは消えないため（.userDefined の常時表示と同じ理由）。
                            // 詳しい説明（Coverage が何か・なぜ判定できないか）は
                            // 「いま出ている判定結果の読み方を変えない」背景情報なので、
                            // 下の折りたたみ側（cranialCoverageDetailNote）に分けている。
                            if vm.isCranialSRSSelected {
                                Text(ConformityCriteria.cranialJudgesTwoOfThreeNote)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            // 背景・方法論の注記の折りたたみ。判定結果の読み方そのものを
                            // 変える情報（上の常時表示の各注記）とは別に格納する
                            // （`vm.showsProtocolBackgroundNotes` に表示条件を集約。
                            // UI 整理: 注記が積み上がり判定そのものより場所を取る、
                            // という指摘への対応）。既定は折りたたんだ状態。
                            if vm.showsProtocolBackgroundNotes {
                                DisclosureGroup("この判定基準について") {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if vm.isCranialSRSSelected {
                                            Text(ConformityCriteria.cranialCoverageDetailNote)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(ConformityCriteria.cranialBoundarySafetyNote)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if vm.isLungSBRTSelected {
                                            Text(ConformityCriteria.scopeNote)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(ConformityCriteria.r50DefinitionNote)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .font(.caption2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("品質指標")
            .dismissibleKeyboard()
            .navigationBarTitleDisplayMode(.inline)
            .infoToolbarButton()
        }
    }

    @ViewBuilder
    private func indexRow(_ label: String, _ value: Double?, format: String, suffix: String = "") -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            if let value {
                Text(String(format: format, value) + suffix)
                    .font(.body.monospacedDigit())
                    .bold()
            } else {
                Text("入力待ち")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 指標 1 行の逸脱判定表示。
    ///
    /// `level == nil` になる理由は 2 つあり、区別する。
    /// - `unconfigured`（`.custom` で施設がその指標の閾値を定めていない）→「未設定」
    /// - それ以外（値が未入力）→「入力待ち」
    /// 「判定していない」ことと「基準内」であることは違う。区別せず一括りに
    /// すると、施設が定めていない指標なのか、単に入力が済んでいないだけなのか
    /// が利用者から見分けられない（品質タブの「入力待ち」と「範囲外」を
    /// 混同しないよう別扱いにした経緯、D1 の「登録なし」と「読めていない」を
    /// 分けた経緯と同じ理由）。
    @ViewBuilder
    private func deviationRow(_ label: String, _ level: DeviationLevel?,
                              unconfigured: Bool = false, useCustomNaming: Bool = false) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            if let level {
                Text(useCustomNaming ? level.customDisplayName : level.displayName)
                    .font(.callout.bold())
                    .foregroundStyle(color(for: level))
            } else if unconfigured {
                Text("未設定")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("入力待ち")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func color(for level: DeviationLevel) -> Color {
        switch level {
        case .perProtocol: .green
        case .minor:       .orange
        case .major:       .red
        }
    }

    /// プロトコル選択メニューの 1 行。
    ///
    /// 試験番号だけでは、どの部位のどの線量分割に対する基準なのかを選ぶ
    /// 時点で判断できない。1 つの Text にまとめる（メニューの行は複数 Text
    /// を並べても 2 行にならないことがあるため）。
    ///
    /// `label` を呼び出し側から明示的に渡す。`selection.menuLabel` に解決
    /// させないのは、`.custom(id)` が id しか持たず名前を解決できないため
    /// （値のコピーを持つと削除・編集への追随が壊れる。上のコメント参照）。
    /// `.custom` を渡す呼び出し側は、一覧から得た実物の `CustomProtocol.name`
    /// をここで直接渡す。
    @ViewBuilder
    private func protocolButton(_ selection: ProtocolSelection, label: String) -> some View {
        Button {
            vm.selectedProtocol = selection
        } label: {
            Text(label)
            if vm.selectedProtocol == selection {
                Image(systemName: "checkmark")
            }
        }
    }
}
