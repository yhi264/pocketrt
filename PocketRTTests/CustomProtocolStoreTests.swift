import Testing
import Foundation
@testable import PocketRT

@Suite("自施設の判定基準の永続化")
struct CustomProtocolStoreTests {

    /// テストごとに使い捨ての URL を返す
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-test-\(UUID().uuidString).json")
    }

    private func sample(name: String = "肺 SBRT 当院基準") -> CustomProtocol {
        CustomProtocol(
            id: UUID().uuidString, name: name, note: "R50% と D2cm のみ規定",
            thresholds: [
                .r50: MetricThreshold(within: 4.5, tolerated: 5.5),
                .d2cm: MetricThreshold(within: 60.0, tolerated: nil)
            ],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("保存と読み込みの往復で内容が一致する")
    func roundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = CustomProtocolStore(fileURL: url)
        let data = CustomProtocolData(
            schemaVersion: CustomProtocolStore.currentSchemaVersion, protocols: [sample()])
        try store.save(data)
        let loaded = try store.load()
        #expect(loaded.protocols == data.protocols)
    }

    @Test("ファイルがなければ空の内容を返す")
    func loadMissingFile() throws {
        let store = CustomProtocolStore(fileURL: tempURL())
        let loaded = try store.load()
        #expect(loaded.protocols.isEmpty)
    }

    @Test("ファイルがあるが解釈できない場合はエラーを返す（空を返して上書きさせない）")
    func throwsOnCorruptedContent() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ これは JSON ではない".utf8).write(to: url)
        #expect(throws: CustomProtocolStoreError.corruptedContent) {
            try CustomProtocolStore(fileURL: url).load()
        }
    }

    @Test("schemaVersion は正しいが本文が壊れている場合もエラーを返す")
    func throwsOnValidEnvelopeWithBrokenBody() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"protocols":"not-an-array"}"#.utf8).write(to: url)
        #expect(throws: CustomProtocolStoreError.corruptedContent) {
            try CustomProtocolStore(fileURL: url).load()
        }
    }

    @Test("schemaVersion キーがない場合もエラーを返す")
    func throwsOnMissingSchemaVersion() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"protocols":[]}"#.utf8).write(to: url)
        #expect(throws: CustomProtocolStoreError.corruptedContent) {
            try CustomProtocolStore(fileURL: url).load()
        }
    }

    @Test("ファイルは存在するが読めない場合はエラーを返す（内容の解釈エラーとは区別する）")
    func throwsOnUnreadableFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        // fileURL の位置にディレクトリを作ると、fileExists は true を返すが
        // Data(contentsOf:) は失敗する。権限や I/O 障害で読めない状況を
        // 確実に再現できる。
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        #expect(throws: CustomProtocolStoreError.unreadableFile) {
            try CustomProtocolStore(fileURL: url).load()
        }
    }

    @Test("未知の schemaVersion は読み込まずエラーを返す")
    func rejectsUnknownSchemaVersion() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":99,"protocols":[]}"#.utf8).write(to: url)
        let store = CustomProtocolStore(fileURL: url)
        #expect(throws: CustomProtocolStoreError.unsupportedSchemaVersion(99)) {
            try store.load()
        }
    }

    @Test("別インスタンスで読み直しても内容が保持される（アプリ再起動相当）")
    func survivesNewStoreInstance() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try CustomProtocolStore(fileURL: url).save(
            CustomProtocolData(schemaVersion: 1, protocols: [sample(name: "再起動後も残る")]))
        let loaded = try CustomProtocolStore(fileURL: url).load()
        #expect(loaded.protocols.map(\.name) == ["再起動後も残る"])
    }
}
