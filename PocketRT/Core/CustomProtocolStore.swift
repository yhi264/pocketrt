import Foundation

/// 保存されるデータ全体
struct CustomProtocolData: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var protocols: [CustomProtocol]

    static let empty = CustomProtocolData(
        schemaVersion: CustomProtocolStore.currentSchemaVersion, protocols: [])
}

enum CustomProtocolStoreError: Error, Equatable {
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

/// 自施設の判定基準を JSON ファイルに保存する。
///
/// `InstitutionalPresetStore`（D1・自施設プリセット）と同じ方式にしている。
/// D1 では永続化まわりで 5 件の欠陥（うち 1 件は復旧不能なクラッシュ）が出た。
/// この store は同じ問題を二度作らないよう、その形をそのまま踏襲している
/// （`InstitutionalPresetStore.swift` と実装は共有していない。理由は
/// Task 2 報告を参照）。
///
/// **`InstitutionalPresetStore` と構造が同一（データ構造とファイル名しか
/// 違わない）。片方でここに起因する欠陥が見つかったら、もう片方も同じ
/// 欠陥を持っていないか必ず確認すること。** D1 はこの構造で実際に 5 件の
/// 欠陥（うち 1 件は復旧不能なクラッシュ）を出した実績がある。共通化は
/// G2 提出後に行う予定。それまでは 2 箇所を手で揃える。
///
/// 保存先の URL を注入できるようにしてある。テストで実際のアプリの
/// 保存先を触らずに検証するため。
struct CustomProtocolStore {
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
        return dir.appendingPathComponent("custom-protocols.json")
    }

    /// アプリが実際に使う保存先の store を作る。
    ///
    /// `defaultURL()` が失敗しうる（Application Support の解決に失敗する）
    /// ことを呼び出し側に押し付けず、ここで一箇所にまとめる。
    /// 失敗時に一時ディレクトリへフォールバックしてはならない。一時ディレクトリは
    /// OS が任意に消しうるため、利用者に「登録なし」に見える形で登録が
    /// 消えかねない。呼び出し側は `try?` で受け、失敗を `loadFailure` として
    /// 扱うこと。
    static func `default`() throws -> CustomProtocolStore {
        CustomProtocolStore(fileURL: try defaultURL())
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
    func load() throws -> CustomProtocolData {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return .empty
        }
        guard let raw = try? Data(contentsOf: fileURL) else {
            throw CustomProtocolStoreError.unreadableFile
        }

        // schemaVersion だけ先に読む。全体のデコードに失敗しても、
        // 未知の形式であることは判別できるようにする。
        // ここで失敗する（JSON として構文解析できない、または
        // schemaVersion キーがない）のは、常に「読めなかった」ことを
        // 意味する。この store が書いたファイルには必ず schemaVersion が
        // 入っているため。
        struct VersionProbe: Decodable { let schemaVersion: Int }
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: raw) else {
            throw CustomProtocolStoreError.corruptedContent
        }
        guard probe.schemaVersion == Self.currentSchemaVersion else {
            throw CustomProtocolStoreError.unsupportedSchemaVersion(probe.schemaVersion)
        }

        guard let decoded = try? JSONDecoder().decode(CustomProtocolData.self, from: raw) else {
            throw CustomProtocolStoreError.corruptedContent
        }
        // デコードできただけでは中身を信頼しない。範囲外の値を持つ基準が
        // 1 件でもあれば corruptedContent として扱う（別途課題として記録した）。
        //
        // 読み込み（インポート）経路も CustomProtocolStoreModel 側で同じ
        // 数値版検証を通しており、そちらで弾かれた内容がここへ到達すること
        // はない。したがってこれは二重の防御である。それでも置く理由は、
        // 書き込み経路が 1 つ増えるたびに検証を足し忘れる余地が生まれる
        // ためで、D1 は実際にその見落としで範囲外の値を保存し、復旧不能な
        // クラッシュに至った。
        //
        // 検証を通った値をそのまま返す（draft で置き換えない）。ここは保存
        // データを読む場所であり、読むついでに内容を書き換えると、保存されて
        // いる値と画面に出る値が食い違う。整形（トリム）は書き込み側の責任。
        for p in decoded.protocols {
            guard case .success = CustomProtocolValidator.validate(
                name: p.name, note: p.note, thresholds: p.thresholds) else {
                throw CustomProtocolStoreError.corruptedContent
            }
        }
        return decoded
    }

    func save(_ data: CustomProtocolData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: fileURL, options: .atomic)
    }
}
