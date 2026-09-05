import Foundation
import Observation

/// `loadFailure` の原因。失敗の種類によって正しい復旧経路が違うため、
/// 文言（`loadFailure: String?`）だけでなく種別を別途保持する（仕様 §4.4）。
///
/// | 種類 | 復旧経路 | データを破棄してよいか |
/// |---|---|---|
/// | `.unreadableFile` | 再読み込み（`reload()`） | **不可。** データは無事（権限・データ保護・I/O 障害という一時的な理由で開けないだけ） |
/// | `.unsupportedSchemaVersion` | アプリの更新を促す（再読み込みも破棄もさせない） | **不可。** データは無事で、ただ新しい形式なだけ |
/// | `.corruptedContent` | 破棄して作り直す（`discardCorruptedData()`） | 可。アプリから二度と読めないので、破棄しても失うものがない |
///
/// `unsupportedSchemaVersion` に破棄を許すのが最も危険である。アプリを更新すれば
/// 読めたはずのデータを、利用者自身の手で消させることになる。回復可能なものを
/// 回復不能にしてはならない。
enum CustomProtocolLoadFailureKind: Equatable, Sendable {
    case unreadableFile
    case unsupportedSchemaVersion(Int)
    case corruptedContent
}

/// 自施設の判定基準（利用者定義プロトコル）を保持する。
///
/// 変更のたびに保存する。件数が少なく（想定は数個〜十数個）、保存の失敗を
/// 利用者が気づかないまま作業を続ける方が害が大きいため。
///
/// `hasStore`（保存先が用意できたか）と `loadFailure`（読めなかったか）の
/// 状態管理は `PresetStoreModel`（D1）と同じ規律に従う。D1 ではこの 2 状態を
/// `loadFailure` 1 つで兼ねたために、保存先が解決できない端末で読み込みを
/// 行うと「復旧成功」と表示しながら、実際には何も保存されないまま登録が
/// 失われる経路ができた。失敗を成功として見せる点で、無言で終わるより悪い。
/// 最初から分ける。
///
/// 書き出しと読み込みを持つ（v2 で追加。v1 は持たなかった。仕様 §6）。
/// 失敗の種類ごとの復旧経路は v1 のまま残し、そこに
/// 読み込みを重ねている（仕様 §4.4）。
///
/// - `unreadableFile` → `reload()`（保存データの読み直し）。
///   **読み込みは出さない。** データは無事であり、置き換えれば無事なものを失う
/// - `unsupportedSchemaVersion` → 復旧経路なし。アプリの更新を待つ
///   （`reload()` も `discardCorruptedData()` も、この種別のときは何もしない）。
///   **読み込みも出さない。** 理由は上と同じ
/// - `corruptedContent` → `discardCorruptedData()`（破棄して作り直す）、
///   または**読み込み**（書き出しておいた内容を取り戻す）。読み込みの方が
///   失うものが無いため、UI では先に出す
///
/// この出し分けが D1 との最大の違いである。D1 は失敗状態を 1 つしか持たない
/// ので「読めなかった＝置き換えてよい」と単純化できた。D2 で同じ単純化を
/// すると、無事なデータを読み込みで消せてしまう。
@Observable
final class CustomProtocolStoreModel {
    private(set) var protocols: [CustomProtocol] = []
    /// 保存に失敗したときの理由。nil なら直近の保存は成功している。
    private(set) var lastSaveError: String?

    @ObservationIgnored private let store: CustomProtocolStore?

    /// 読み込みに失敗したか。失敗している間は保存しない。
    /// 空のまま上書きすると、読めなかっただけの登録が本当に消えるため。
    ///
    /// `store == nil`（保存先そのものが無い）ときもここに文言を立てるが、
    /// 性質が違うことに注意する。`store` が存在するときの `loadFailure`
    /// は「保存データを読めなかった」状態で、種別に応じた復旧経路が
    /// ある（`loadFailureKind` 参照）。`store == nil` はそもそも保存先が
    /// 無いので、読み直しても何も保存できず、読み込みで解除してはならない。
    /// この区別は `hasStore` で判定する（`loadFailure` の有無だけでは
    /// 2 つの状態を見分けられない）。
    private(set) var loadFailure: String?

    /// `loadFailure` の原因。`store == nil` のとき（保存先そのものが無い）は
    /// 立てない。3 種の復旧経路のどれにも該当せず、`hasStore` で別に判定する
    /// ため。UI（Task 6 の編集画面）はこれを見て復旧手段を出し分ける。
    private(set) var loadFailureKind: CustomProtocolLoadFailureKind?

    /// 保存先が用意できているか。`false` の間は、読み込みを含めて
    /// いかなる変更操作もできない（できるように見せてもいけない）。
    /// `loadFailure` と違い、この状態は読み込みで解除されない。
    var hasStore: Bool { store != nil }

    /// `store` が `nil` になるのは、保存先そのものが決まらなかった場合
    /// （`CustomProtocolStore.default()` の失敗）。ここで一時ディレクトリ
    /// などにフォールバックせず、`loadFailure` を立てて空のまま扱う。
    /// 一時ディレクトリへ黙って保存すると、利用者には「登録なし」に見え、
    /// OS がファイルを消せば登録も静かに消える。
    init(store: CustomProtocolStore?) {
        self.store = store
        guard let store else {
            loadFailure = String(localized: "保存先を用意できませんでした。この端末では自施設の判定基準を保存できません。")
            return
        }
        load(from: store)
    }

    /// 保存データを読み直す。`unreadableFile` からの復旧経路。
    ///
    /// 保存先が無い（`hasStore == false`）場合は何もしない。読み直す先が
    /// そもそも無いので、呼んでも `loadFailure` を解除できない
    /// （解除すると「保存先が無い」ことを見失う）。
    func reload() {
        guard let store else { return }
        load(from: store)
    }

    /// 破損した保存データを破棄し、空の状態で作り直す。`corruptedContent`
    /// からの復旧経路。
    ///
    /// `loadFailureKind == .corruptedContent` のときだけ働く。呼び出し側
    /// （UI）のガードに頼らず、ここで種別を確認する。D1 では「UI がガード
    /// しているから大丈夫」という前提が、呼び出し元が増えたときに破れた。
    ///
    /// `unreadableFile` はデータが無事（一時的な理由で開けないだけ）なので
    /// 破棄しない。`unsupportedSchemaVersion` もデータは無事で、ただ新しい
    /// 形式なだけなので破棄しない。破棄すると、アプリを更新すれば読めた
    /// はずのデータを利用者自身の手で消すことになる（仕様 §4.4 で「この
    /// 1 点だけは絶対に間違えないこと」と念を押されている）。
    ///
    /// `hasStore == false` のときも何もしない。破棄して書き直す保存先が
    /// そもそも無い。
    ///
    /// - Returns: 実際に破棄したら `true`。種別が合わない、または保存先が
    ///   無く何もしなかった場合は `false`。
    @discardableResult
    func discardCorruptedData() -> Bool {
        guard hasStore, loadFailureKind == .corruptedContent else { return false }
        protocols = []
        loadFailure = nil
        loadFailureKind = nil
        persist()
        return true
    }

    private func load(from store: CustomProtocolStore) {
        do {
            let data = try store.load()
            protocols = data.protocols
            loadFailure = nil
            loadFailureKind = nil
        } catch CustomProtocolStoreError.unsupportedSchemaVersion(let v) {
            loadFailure = String(localized: "保存データが新しい形式です（version \(v)）。アプリを更新してください。誤って上書きしないよう、変更は保存されません。")
            loadFailureKind = .unsupportedSchemaVersion(v)
        } catch CustomProtocolStoreError.unreadableFile {
            // 内容が壊れているのではなく、開けなかった（権限・データ保護・I/O 障害など）。
            // 原因が違うので、利用者が取れる行動も違う。端末のロック解除やアプリの
            // 再起動で直ることがある一方、内容が壊れている場合は書き出しからの
            // 復旧が必要になる。同じ文言にすると誤った対処に誘導しかねない。
            loadFailure = String(localized: "保存データを開けませんでした。端末のロックを解除してからアプリを再起動すると読めることがあります。誤って上書きしないよう、変更は保存されません。")
            loadFailureKind = .unreadableFile
        } catch CustomProtocolStoreError.corruptedContent {
            loadFailure = String(localized: "保存データを読めませんでした。誤って上書きしないよう、変更は保存されません。")
            loadFailureKind = .corruptedContent
        } catch {
            // CustomProtocolStore.load() が投げるのは上記 3 種のみだが、
            // 想定外のエラーに備えて残す。種別を特定できないので
            // `loadFailureKind` は立てない。破棄（`discardCorruptedData()`）
            // は `.corruptedContent` のときしか働かないため、ここで
            // 立てないと復旧経路が無くなるが、正体不明のエラーを
            // 「破棄してよい」と誤って判定するよりは安全側に倒す。
            loadFailure = String(localized: "保存データを読めませんでした。誤って上書きしないよう、変更は保存されません。")
        }
    }

    func add(_ p: CustomProtocol) {
        protocols.append(p)
        persist()
    }

    func update(_ p: CustomProtocol) {
        guard let i = protocols.firstIndex(where: { $0.id == p.id }) else { return }
        protocols[i] = p
        persist()
    }

    func delete(id: String) {
        protocols.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        // 読み込みに失敗している間（保存先が決まらなかった場合を含む）は
        // 保存しない。空の状態で上書きすると、読めなかっただけで残っていた
        // 登録が本当に消える。
        guard loadFailure == nil, let store else { return }
        let data = CustomProtocolData(
            schemaVersion: CustomProtocolStore.currentSchemaVersion, protocols: protocols)
        do {
            try store.save(data)
            lastSaveError = nil
        } catch {
            lastSaveError = String(localized: "保存に失敗しました")
        }
    }
}

// MARK: - 書き出しと読み込み

/// 読み込み（インポート）の結果。
///
/// `Error` に準拠しているのは実際に `throw` されるからではなく、
/// `decodeAndValidate` の戻り値 `Result<CustomProtocolData, CustomProtocolImportResult>`
/// の失敗側の型として使うため（`Result` の `Failure` は `Error` 制約を持つ）。
/// この型が実際に `throw`/`catch` される経路はない。
///
/// D1（`ImportResult`）と似ているが同じではない。**`blockedByIntactData` は
/// D1 に存在しない。** D1 は失敗状態を 1 つしか持たないため「読めなかった＝
/// 置き換えてよい」と単純化できたが、D2 は失敗の種類を区別しており、
/// そのうち 2 種（`unreadableFile` / `unsupportedSchemaVersion`）は
/// **データが無事である**。無事なデータを読み込みで置き換えるのは、
/// 仕様 §4.4 が禁じている「破棄」と実質的に同じ行為になる。
enum CustomProtocolImportResult: Error, Equatable, Sendable {
    case success(added: Int, updated: Int)
    /// 壊れた保存ファイル（`corruptedContent`）を、読み込んだ内容で置き換えた
    case replaced(count: Int)
    case unsupportedVersion(Int)
    case invalidFormat
    /// デコードはできたが、範囲外の値を持つ基準があった。
    /// 1 件でも不正なら取り込みを行わない（部分的に取り込むと、
    /// 利用者が「何が入って何が入らなかったか」を確認できないため）。
    case invalidProtocolValues(names: [String])
    /// 保存先そのものが無い（`hasStore == false`）。読み込んでも保存
    /// できないので、取り込みを行わない。
    case storeUnavailable
    /// 保存データを読めていないが、**そのデータは無事である**
    /// （`unreadableFile` / `unsupportedSchemaVersion`）。
    ///
    /// 合流もできない（既存の内容が分からないため、id が一致するかを
    /// 判定できない）。置き換えもできない（無事なデータを消すことになる）。
    /// したがって何もしない。利用者には、まず表示中の復旧手段
    /// （再読み込み、またはアプリの更新）を先に行うよう伝える。
    case blockedByIntactData(CustomProtocolLoadFailureKind)
    /// 保存データを読めておらず、その原因も特定できていない
    /// （`loadFailure != nil` かつ `loadFailureKind == nil`）。
    /// 破棄してよいか判断できないので、置き換えない。
    case blockedByUnknownFailure
}

extension CustomProtocolStoreModel {

    /// 書き出しの導線を出してよいか。
    ///
    /// 読み込みに失敗している間は出さない。そのとき `protocols` は空であり、
    /// 空の内容を書き出しても意味がないうえ、それを後で読み込むと本当に
    /// 空になる。「バックアップを取った」と思わせて中身が無いのが最も悪い。
    var canExport: Bool { hasStore && loadFailure == nil }

    /// 読み込みの導線を出してよいか。
    ///
    /// 通常時に加えて、`corruptedContent`（二度と読めない）のときだけ許す。
    /// これは破棄（`discardCorruptedData()`）より good な復旧手段である——
    /// 破棄は登録を失うが、読み込みは書き出しておいた内容を取り戻せる。
    ///
    /// `unreadableFile` と `unsupportedSchemaVersion` では出さない。
    /// どちらもデータは無事で、置き換えれば無事なものを失う。
    var canImport: Bool {
        guard hasStore else { return false }
        guard loadFailure != nil else { return true }
        return loadFailureKind == .corruptedContent
    }

    /// 現在の内容を JSON にする。保存ファイルと同じ形式・同じ整形にする
    /// （書き出したファイルが、そのまま保存ファイルの代わりになる）。
    func exportData() -> Data? {
        guard canExport else { return nil }
        let data = CustomProtocolData(
            schemaVersion: CustomProtocolStore.currentSchemaVersion, protocols: protocols)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    /// 現在の状態で読み込みを行ってよいかを判定する。
    /// 判定できない状態を `CustomProtocolImportResult` として返す。
    private func importBlocker() -> CustomProtocolImportResult? {
        guard hasStore else { return .storeUnavailable }
        guard loadFailure != nil else { return nil }
        if let kind = loadFailureKind {
            return kind == .corruptedContent ? nil : .blockedByIntactData(kind)
        }
        return .blockedByUnknownFailure
    }

    /// デコードと範囲検証だけを行い、状態を変更しない。
    ///
    /// **必ず `CustomProtocolValidator` の数値版を通す。** D1 では取り込み経路が
    /// 検証を迂回し、範囲外の値が保存されて復旧不能なクラッシュに至った
    /// （別途課題として記録した）。文字列に戻して文字列版に通してはならない。
    /// 書式化を経由する分、値が変わる余地を作る。
    ///
    /// 1 件でも不正なら、ファイル全体を取り込まない。部分的に取り込むと
    /// 利用者が「何が入って何が入らなかったか」を確認できず、臨床判断に
    /// 関わる閾値としては「一部だけ入った」より「何も変えていない」方が安全。
    private func decodeAndValidate(_ raw: Data) -> Result<CustomProtocolData, CustomProtocolImportResult> {
        struct VersionProbe: Decodable { let schemaVersion: Int }
        if let probe = try? JSONDecoder().decode(VersionProbe.self, from: raw),
           probe.schemaVersion != CustomProtocolStore.currentSchemaVersion {
            return .failure(.unsupportedVersion(probe.schemaVersion))
        }
        guard let decoded = try? JSONDecoder().decode(CustomProtocolData.self, from: raw) else {
            return .failure(.invalidFormat)
        }

        var invalidNames: [String] = []
        var validated: [CustomProtocol] = []
        for p in decoded.protocols {
            switch CustomProtocolValidator.validate(
                name: p.name, note: p.note, thresholds: p.thresholds) {
            case .success(let draft):
                validated.append(CustomProtocol(
                    id: p.id, name: draft.name, note: draft.note,
                    thresholds: draft.thresholds, createdAt: p.createdAt))
            case .failure:
                // 名前が空の基準も弾かれる。そのまま並べると空文字が
                // 区切り文字だけになって何件あるか分からないので、
                // place holder を置いて件数が読めるようにする。
                invalidNames.append(p.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? String(localized: "（名前なし）") : p.name)
            }
        }
        guard invalidNames.isEmpty else {
            return .failure(.invalidProtocolValues(names: invalidNames))
        }
        return .success(CustomProtocolData(
            schemaVersion: decoded.schemaVersion, protocols: validated))
    }

    /// 取り込む前に内容を確かめる。状態は変更しない。
    ///
    /// 他人が書き出した JSON を読み込むと、それが自施設の基準として扱われ、
    /// 判定パネルに「利用者が登録した基準による」と表示されたまま、実際には
    /// 別の施設の基準で判定することになる。プリセット（D1）より強い臨床的
    /// 言明を生むため、取り込み前の確認は省けない。ここでは検証だけを行い、
    /// 確認ダイアログに必要な情報を返す。
    func previewImport(_ raw: Data) -> Result<(data: CustomProtocolData, willReplace: Bool), CustomProtocolImportResult> {
        if let blocker = importBlocker() { return .failure(blocker) }
        // ここに来た時点で、loadFailure != nil なら種別は corruptedContent に限られる。
        return decodeAndValidate(raw).map { ($0, loadFailure != nil) }
    }

    /// 検証済みの内容を実際に適用する。`previewImport` で確認を取った後に呼ぶ。
    ///
    /// 通常は既存を消さず、id が一致するものだけ上書きする。
    /// `corruptedContent` のときだけ、読み込んだ内容で置き換えて保存を再開する。
    ///
    /// 呼び出し側（UI）のガードに頼らず、ここでも `importBlocker()` を通す。
    /// D1 では「UI がガードしているから大丈夫」という前提が、呼び出し元が
    /// 増えたときに破れた。
    @discardableResult
    func applyImport(_ decoded: CustomProtocolData) -> CustomProtocolImportResult {
        if let blocker = importBlocker() { return blocker }

        if loadFailure != nil {
            protocols = decoded.protocols
            loadFailure = nil
            loadFailureKind = nil
            persist()
            return .replaced(count: decoded.protocols.count)
        }

        var added = 0, updated = 0
        for p in decoded.protocols {
            if let i = protocols.firstIndex(where: { $0.id == p.id }) {
                protocols[i] = p
                updated += 1
            } else {
                protocols.append(p)
                added += 1
            }
        }
        persist()
        return .success(added: added, updated: updated)
    }

    /// 確認を挟まない版。`previewImport` と `applyImport` を続けて呼ぶ。
    /// 取り込み前の確認 UI を持たないテストから使う。
    @discardableResult
    func importData(_ raw: Data) -> CustomProtocolImportResult {
        if let blocker = importBlocker() { return blocker }
        switch decodeAndValidate(raw) {
        case .success(let decoded): return applyImport(decoded)
        case .failure(let result): return result
        }
    }
}
