import Foundation

enum InstitutionalPresetStoreError: Error, Equatable {
    /// このバージョンのアプリが読めない形式
    case unsupportedSchemaVersion(Int)
    /// ファイルは存在するが内容を解釈できない（構文エラー・型不一致・
    /// schemaVersion 欠落など）。ここで空を返して呼び出し側に上書きさせると、
    /// 利用者の登録が消える。ファイルがない場合（正常な初回起動）とは
    /// 区別しなければならない。
    case corruptedContent
    /// ファイルは存在するがバイト列として読み出せない（権限・データ保護・
    /// I/O 障害など）。内容を解釈する以前の問題なので corruptedContent とは
    /// 分ける。ここでも空を返すと、ファイルがない場合と区別がつかなくなり、
    /// 次の保存で読めなかっただけの登録を上書きしてしまう。
    case unreadableFile
}

/// 自施設プリセットを JSON ファイルに保存する。
///
/// **`Core/CustomProtocolStore.swift`（D2・自施設の判定基準）と構造が同一
/// （データ構造とファイル名しか違わない）。片方でここに起因する欠陥が
/// 見つかったら、もう片方も同じ欠陥を持っていないか必ず確認すること。**
/// この store は過去に 5 件の欠陥（うち 1 件は復旧不能なクラッシュ）を
/// 出した実績がある。共通化は G2 提出後に行う予定。それまでは
/// 2 箇所を手で揃える。
///
/// 保存先の URL を注入できるようにしてある。テストで実際のアプリの
/// 保存先を触らずに検証するため。
struct InstitutionalPresetStore {
    static let currentSchemaVersion = 1

    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// アプリが実際に使う保存先
    static func defaultURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return dir.appendingPathComponent("institutional-presets.json")
    }

    /// アプリが実際に使う保存先の store を作る。
    ///
    /// `defaultURL()` が失敗しうる（Application Support の解決に失敗する）
    /// ことを呼び出し側に押し付けず、ここで一箇所にまとめる。
    /// 失敗時に一時ディレクトリへフォールバックしてはならない。一時ディレクトリは
    /// OS が任意に消しうるため、利用者に「登録なし」に見える形で登録が
    /// 消えかねない。呼び出し側は `try?` で受け、失敗を `loadFailure` として
    /// 扱うこと。
    static func `default`() throws -> InstitutionalPresetStore {
        InstitutionalPresetStore(fileURL: try defaultURL())
    }

    /// 読み込む。
    ///
    /// ファイルがない場合だけ空を返す（初回起動として正常）。
    /// ファイルは存在するがバイト列として読み出せない場合（権限・データ
    /// 保護・I/O 障害など）は `.unreadableFile` を投げる。ファイルは存在
    /// するが内容を解釈できない場合（構文エラー・型不一致・schemaVersion
    /// 欠落）は `.corruptedContent` を投げる。いずれも、ここで空を返して
    /// 呼び出し側に上書きさせると、利用者の登録が消える。「読めなかった」
    /// ことと「何もなかった」ことは呼び出し側が区別できなければならない。
    /// schemaVersion が既知だが未対応の場合は `.unsupportedSchemaVersion` を
    /// 投げる。将来の形式を空と誤認して上書き保存すると、その端末の登録が
    /// 消えるため。
    func load() throws -> InstitutionalPresetData {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return .empty
        }
        guard let raw = try? Data(contentsOf: fileURL) else {
            throw InstitutionalPresetStoreError.unreadableFile
        }

        // schemaVersion だけ先に読む。全体のデコードに失敗しても、
        // 未知の形式であることは判別できるようにする。
        // ここで失敗する（JSON として構文解析できない、または
        // schemaVersion キーがない）のは、常に「読めなかった」ことを
        // 意味する。この store が書いたファイルには必ず schemaVersion が
        // 入っているため。
        struct VersionProbe: Decodable { let schemaVersion: Int }
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: raw) else {
            throw InstitutionalPresetStoreError.corruptedContent
        }
        guard probe.schemaVersion == Self.currentSchemaVersion else {
            throw InstitutionalPresetStoreError.unsupportedSchemaVersion(probe.schemaVersion)
        }

        guard let decoded = try? JSONDecoder().decode(InstitutionalPresetData.self, from: raw) else {
            throw InstitutionalPresetStoreError.corruptedContent
        }
        return decoded
    }

    func save(_ data: InstitutionalPresetData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: fileURL, options: .atomic)
    }
}
