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
/// D2 の v1 は書き出し・読み込み（インポート/エクスポート）機能を持たない
/// （仕様 §6）。D1 の設計メモには「読み込みは、壊れた保存ファイルを置き換える
/// 唯一の復旧手段でもある。禁止すると行き止まりになる」とある。D2 v1 はその
/// 手段を持たないため、代わりに失敗の種類ごとに専用の復旧経路を持つ（仕様 §4.4）。
///
/// - `unreadableFile` → `reload()`（保存データの読み直し）
/// - `unsupportedSchemaVersion` → 復旧経路なし。アプリの更新を待つ
///   （`reload()` も `discardCorruptedData()` も、この種別のときは何もしない）
/// - `corruptedContent` → `discardCorruptedData()`（破棄して作り直す）
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
