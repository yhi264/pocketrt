import Foundation
import Observation

/// 自施設プリセットと内蔵プリセットの非表示設定を保持する。
///
/// 変更のたびに保存する。件数が少なく（想定は数十件）、
/// 保存の失敗を利用者が気づかないまま作業を続ける方が害が大きいため。
@Observable
final class PresetStoreModel {
    private(set) var presets: [InstitutionalPreset] = []
    private(set) var hiddenBuiltInKeys: Set<String> = []
    /// 保存に失敗したときの理由。nil なら直近の保存は成功している。
    private(set) var lastSaveError: String?

    @ObservationIgnored private let store: InstitutionalPresetStore?

    /// 読み込みに失敗したか。失敗している間は保存しない。
    /// 空のまま上書きすると、読めなかっただけの登録が本当に消えるため。
    ///
    /// `store == nil`（保存先そのものが無い）ときもここに文言を立てるが、
    /// 性質が違うことに注意する。`store` が存在するときの `loadFailure`
    /// は「保存データを読めなかった」状態で、読み込み（インポート）で
    /// 解除できる復旧経路がある。`store == nil` はそもそも保存先が無いので、
    /// 読み込んでも何も保存できず、読み込みで解除してはならない。
    /// この区別は `hasStore` で判定する（`loadFailure` の有無だけでは
    /// 2 つの状態を見分けられない）。
    private(set) var loadFailure: String?

    /// 保存先が用意できているか。`false` の間は、読み込みを含めて
    /// いかなる変更操作もできない（できるように見せてもいけない）。
    /// `loadFailure` と違い、この状態は読み込みで解除されない。
    var hasStore: Bool { store != nil }

    /// `store` が `nil` になるのは、保存先そのものが決まらなかった場合
    /// （`InstitutionalPresetStore.default()` の失敗）。ここで一時ディレクトリ
    /// などにフォールバックせず、`loadFailure` を立てて空のまま扱う。
    /// 一時ディレクトリへ黙って保存すると、利用者には「登録なし」に見え、
    /// OS がファイルを消せば登録も静かに消える。
    init(store: InstitutionalPresetStore?) {
        self.store = store
        guard let store else {
            loadFailure = String(localized: "保存先を用意できませんでした。この端末では自施設プリセットを保存できません。")
            return
        }
        do {
            let data = try store.load()
            presets = data.presets
            hiddenBuiltInKeys = Set(data.hiddenBuiltInKeys)
        } catch InstitutionalPresetStoreError.unsupportedSchemaVersion(let v) {
            loadFailure = String(localized: "保存データが新しい形式です（version \(v)）。アプリを更新してください。誤って上書きしないよう、変更は保存されません。")
        } catch InstitutionalPresetStoreError.unreadableFile {
            // 内容が壊れているのではなく、開けなかった（権限・データ保護・I/O 障害など）。
            // 原因が違うので、利用者が取れる行動も違う。端末のロック解除やアプリの
            // 再起動で直ることがある一方、内容が壊れている場合は書き出しからの
            // 復旧が必要になる。同じ文言にすると誤った対処に誘導しかねない。
            loadFailure = String(localized: "保存データを開けませんでした。端末のロックを解除してからアプリを再起動すると読めることがあります。誤って上書きしないよう、変更は保存されません。")
        } catch {
            loadFailure = String(localized: "保存データを読めませんでした。誤って上書きしないよう、変更は保存されません。")
        }
    }

    /// 非表示にしていない内蔵プリセット
    func visibleBuiltIns(category: PresetCategory) -> [FractionationPreset] {
        FractionationPresets.byCategory(category).filter { !hiddenBuiltInKeys.contains($0.id) }
    }

    func add(_ preset: InstitutionalPreset) {
        presets.append(preset)
        persist()
    }

    func update(_ preset: InstitutionalPreset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
        persist()
    }

    func delete(id: String) {
        presets.removeAll { $0.id == id }
        persist()
    }

    func setHidden(_ hidden: Bool, key: String) {
        if hidden { hiddenBuiltInKeys.insert(key) } else { hiddenBuiltInKeys.remove(key) }
        persist()
    }

    fileprivate func persist() {
        // 読み込みに失敗している間（保存先が決まらなかった場合を含む）は
        // 保存しない。空の状態で上書きすると、読めなかっただけで残っていた
        // 登録が本当に消える。
        guard loadFailure == nil, let store else { return }
        let data = InstitutionalPresetData(
            schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
            presets: presets,
            hiddenBuiltInKeys: hiddenBuiltInKeys.sorted())
        do {
            try store.save(data)
            lastSaveError = nil
        } catch {
            lastSaveError = String(localized: "保存に失敗しました")
        }
    }
}

/// `Error` に準拠しているのは実際に `throw` されるからではなく、
/// `decodeAndValidate` の戻り値 `Result<InstitutionalPresetData, ImportResult>`
/// の失敗側の型として使うため（`Result` の `Failure` は `Error` 制約を持つ）。
/// この型が実際に `throw`/`catch` される経路はない。
enum ImportResult: Error, Equatable, Sendable {
    case success(added: Int, updated: Int)
    /// 壊れた保存ファイルを、読み込んだ内容で置き換えた
    case replaced(count: Int)
    case unsupportedVersion(Int)
    case invalidFormat
    /// デコードはできたが、範囲外の値を持つプリセットがあった。
    /// 1 件でも不正なら取り込みを行わない（部分的に取り込むと、
    /// 利用者が「何が入って何が入らなかったか」を確認できないため）。
    /// 弾いた対象を特定できるよう名前を保持する。
    case invalidPresetValues(names: [String])
    /// 保存先そのものが無い（`hasStore == false`）。読み込んでも保存
    /// できないので、取り込みを行わない。`replaced` と混同してはならない。
    /// `replaced` は「保存先はあるがデータを読めなかった」からの復旧で
    /// あり、こちらは「保存先が無い」ので読み込みで解決しない。
    case storeUnavailable
}

extension PresetStoreModel {
    /// 現在の内容を JSON にする
    func exportData() -> Data? {
        let data = InstitutionalPresetData(
            schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
            presets: presets, hiddenBuiltInKeys: hiddenBuiltInKeys.sorted())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    /// デコードと範囲検証だけを行い、状態を変更しない。
    ///
    /// 取り込み前に内容を利用者に確認させる（読み込む前に何が起きるかを
    /// 明示する）ために、検証と適用を分けている。エラーで終わる経路は
    /// `ImportResult` としてそのまま返し、検証を通った場合だけ
    /// `applyImport` に渡せる形にする。
    private func decodeAndValidate(_ raw: Data) -> Result<InstitutionalPresetData, ImportResult> {
        struct VersionProbe: Decodable { let schemaVersion: Int }
        if let probe = try? JSONDecoder().decode(VersionProbe.self, from: raw),
           probe.schemaVersion != InstitutionalPresetStore.currentSchemaVersion {
            return .failure(.unsupportedVersion(probe.schemaVersion))
        }
        guard let decoded = try? JSONDecoder().decode(InstitutionalPresetData.self, from: raw) else {
            return .failure(.invalidFormat)
        }

        // Codable と schemaVersion しか検査していない時点では、範囲外の値
        // （例: totalDose が 1e100）が素通りしうる。そのような値は
        // regimenLabel の Int() 変換で実行時にトラップする。検証ロジックは
        // PresetValidator に一本化してあるので、ここでも同じものを呼ぶ。
        // 1 件でも不正なら、ファイル全体を取り込まない。部分的に取り込むと
        // 利用者が「何が入って何が入らなかったか」を確認できず、臨床で使う
        // 値としては「一部だけ入った」より「何も変えていない」方が安全。
        var invalidNames: [String] = []
        var validated: [InstitutionalPreset] = []
        for p in decoded.presets {
            switch PresetValidator.validate(name: p.name, totalDose: p.totalDose,
                                            fractions: p.fractions, alphaBeta: p.alphaBeta,
                                            note: p.note) {
            case .success(let draft):
                validated.append(InstitutionalPreset(
                    id: p.id, name: draft.name, totalDose: draft.totalDose,
                    fractions: draft.fractions, alphaBeta: draft.alphaBeta,
                    note: draft.note, createdAt: p.createdAt))
            case .failure:
                invalidNames.append(p.name)
            }
        }
        guard invalidNames.isEmpty else {
            return .failure(.invalidPresetValues(names: invalidNames))
        }

        return .success(InstitutionalPresetData(
            schemaVersion: decoded.schemaVersion, presets: validated,
            hiddenBuiltInKeys: decoded.hiddenBuiltInKeys))
    }

    /// 取り込む前に内容を確かめる。状態は変更しない。
    ///
    /// `.confirmationDialog` に必要な情報（件数と、合流か置き換えかの
    /// 区別）をあわせて返す。`willReplace` は呼び出し時点の `loadFailure`
    /// で決まる（`applyImport` はこの後の状態変化に関わらず、渡された
    /// データをその区別に従って処理する）。
    ///
    /// 保存先が無い（`hasStore == false`）場合は検証すら行わず
    /// `.storeUnavailable` を返す。呼び出し側（UI）は通常この状態で
    /// 読み込みの導線自体を出さないが、ここでも防御しておく。
    func previewImport(_ raw: Data) -> Result<(data: InstitutionalPresetData, willReplace: Bool), ImportResult> {
        guard hasStore else { return .failure(.storeUnavailable) }
        return decodeAndValidate(raw).map { ($0, loadFailure != nil) }
    }

    /// 検証済みの内容を実際に適用する。`previewImport` で確認を取った後に呼ぶ。
    ///
    /// 既存は消さず、id が一致するものだけ上書きする（通常）。ただし
    /// 保存ファイルが壊れて読めなかった場合、既存の内容は存在しないので
    /// 合流しようがない。読み込んだ内容で置き換え、保存を再開する。
    /// 書き出しておいたファイルからの読み込みが、行き止まりから抜ける
    /// 唯一の手段になる。
    ///
    /// 保存先が無い（`hasStore == false`）場合は、この「置き換え」扱いに
    /// してはならない。`loadFailure` を `nil` にして `.replaced` を返すと、
    /// 実際には何も保存されていないのに「復旧した」と表示することになる
    /// （persist() は store が無ければ何もしないため、次回起動時には
    /// 登録が失われている）。保存先が無い間は `loadFailure` を解除せず、
    /// `.storeUnavailable` を返して何もしない。
    @discardableResult
    func applyImport(_ decoded: InstitutionalPresetData) -> ImportResult {
        guard hasStore else { return .storeUnavailable }
        if loadFailure != nil {
            presets = decoded.presets
            hiddenBuiltInKeys = Set(decoded.hiddenBuiltInKeys)
            loadFailure = nil
            persist()
            return .replaced(count: decoded.presets.count)
        }

        var added = 0, updated = 0
        for p in decoded.presets {
            if let i = presets.firstIndex(where: { $0.id == p.id }) {
                presets[i] = p
                updated += 1
            } else {
                presets.append(p)
                added += 1
            }
        }
        hiddenBuiltInKeys.formUnion(decoded.hiddenBuiltInKeys)
        persist()
        return .success(added: added, updated: updated)
    }

    /// 読み込む。既存は消さず、id が一致するものだけ上書きする。
    ///
    /// `previewImport` と `applyImport` を続けて呼ぶだけの、確認を挟まない
    /// 版。取り込み前の確認 UI を持たないテストや、確認済みの内容を
    /// そのまま適用する経路から使う。
    @discardableResult
    func importData(_ raw: Data) -> ImportResult {
        switch decodeAndValidate(raw) {
        case .success(let decoded):
            return applyImport(decoded)
        case .failure(let result):
            return result
        }
    }
}
