import Testing
import Foundation
@testable import PocketRT

@Suite("自施設の判定基準の保持")
struct CustomProtocolStoreModelTests {

    private func tempStore() -> CustomProtocolStore {
        CustomProtocolStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-model-\(UUID().uuidString).json"))
    }

    private func sample(_ name: String) -> CustomProtocol {
        CustomProtocol(id: UUID().uuidString, name: name,
                       note: nil, thresholds: [.r50: MetricThreshold(within: 4.5, tolerated: nil)],
                       createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("追加した内容が保存され、読み直せる")
    func addPersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("肺 SBRT 当院基準"))
        // 別インスタンスで読み直す
        let reloaded = CustomProtocolStoreModel(store: store)
        #expect(reloaded.protocols.map(\.name) == ["肺 SBRT 当院基準"])
    }

    @Test("更新した内容が保存される")
    func updatePersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        var p = sample("変更前")
        model.add(p)
        p.name = "変更後"
        model.update(p)
        #expect(CustomProtocolStoreModel(store: store).protocols.map(\.name) == ["変更後"])
    }

    @Test("削除した内容が保存される")
    func deletePersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        let p = sample("肺 SBRT 当院基準")
        model.add(p)
        model.delete(id: p.id)
        #expect(CustomProtocolStoreModel(store: store).protocols.isEmpty)
    }

    @Test("store が nil（保存先が決まらない）場合も loadFailure が立ち、保存しない")
    func nilStoreSetsLoadFailure() throws {
        let model = CustomProtocolStoreModel(store: nil)
        #expect(model.loadFailure != nil, "保存先が決まらなかったことを利用者に伝えられなければならない")
        #expect(!model.hasStore)
        #expect(model.protocols.isEmpty)

        // persist() が何もしないこと（クラッシュしない、状態が変わらないことで確認する）
        model.add(sample("追加"))
        #expect(model.loadFailure != nil)
        #expect(model.protocols.count == 1, "メモリ上の一覧は更新される（persist しないだけ）")
    }

    @Test("store が nil のとき、reload しても「保存先が無い」状態は解除されない")
    func reloadDoesNotClearNilStoreState() throws {
        let model = CustomProtocolStoreModel(store: nil)
        #expect(model.loadFailure != nil)
        #expect(!model.hasStore)

        model.reload()

        #expect(model.loadFailure != nil, "保存先が無い状態が読み込みで解除されてはいけない")
        #expect(model.protocols.isEmpty, "保存先が無いので何も読み込まれない")
        #expect(!model.hasStore)
    }

    @Test("読み込みに失敗した場合は保存せず、既存のファイルを壊さない")
    func doesNotOverwriteWhenLoadFailed() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-broken-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // 外側は正しいが本文が壊れているファイル。部分書き込みや手動編集で起こる。
        let broken = #"{"schemaVersion":1,"protocols":"not-an-array"}"#
        try Data(broken.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailure != nil, "読めなかったことを利用者に伝えられなければならない")

        // この状態で編集しても、元のファイルを上書きしない
        model.add(sample("追加"))
        let after = try String(contentsOf: url, encoding: .utf8)
        #expect(after == broken, "読めなかっただけの登録を上書きで消してはいけない")
    }

    @Test("ファイルが存在するのに読めない場合も loadFailure が立ち、保存を止める")
    func unreadableFileSetsLoadFailure() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-unreadable-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // fileURL の位置にディレクトリを作ると、fileExists は true を返すが
        // Data(contentsOf:) は失敗する。
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailure != nil, "開けなかったことを利用者に伝えられなければならない")
        #expect(model.protocols.isEmpty)

        // この状態で編集しても保存が走らない（ディレクトリのままであること）
        model.add(sample("追加"))
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        #expect(isDir.boolValue, "persist() が働いてディレクトリを上書きしてはいけない")
    }

    @Test("破損からの復旧が reload() で通る")
    func reloadRecoversFromCorruptedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-recover-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // 外側は正しいが本文が壊れているファイル
        try Data(#"{"schemaVersion":1,"protocols":"not-an-array"}"#.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailure != nil, "読めなかったことを保持していなければならない")

        // ファイルが（何らかの経路で）正しい内容に直っている状況を再現する
        let fixed = CustomProtocolData(schemaVersion: 1, protocols: [sample("復旧したもの")])
        try JSONEncoder().encode(fixed).write(to: url)

        model.reload()

        #expect(model.loadFailure == nil, "復旧したら保存を再開できなければならない")
        #expect(model.protocols.map(\.name) == ["復旧したもの"])

        // 実際に保存を再開できること（このあとの変更が反映される）
        model.add(sample("復旧後に追加したもの"))
        let reloaded = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(reloaded.protocols.map(\.name) == ["復旧したもの", "復旧後に追加したもの"])
    }

    @Test("reload はまだ壊れているファイルに対しては loadFailure を解除しない")
    func reloadKeepsLoadFailureWhenStillBroken() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-stillbroken-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"protocols":"not-an-array"}"#.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailure != nil)

        model.reload()

        #expect(model.loadFailure != nil, "直っていないファイルを読み直しても復旧してはいけない")
        #expect(model.protocols.isEmpty)
    }

    // MARK: - 失敗の種類ごとの復旧経路（仕様 §4.4）

    @Test("失敗の種類が保持され、呼び出し側から判別できる（内容破損）")
    func loadFailureKindForCorruptedContent() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-kind-corrupted-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"protocols":"not-an-array"}"#.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .corruptedContent)
    }

    @Test("失敗の種類が保持され、呼び出し側から判別できる（読み取り不能）")
    func loadFailureKindForUnreadableFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-kind-unreadable-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .unreadableFile)
    }

    @Test("失敗の種類が保持され、呼び出し側から判別できる（未対応バージョン）")
    func loadFailureKindForUnsupportedSchemaVersion() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-kind-version-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":99,"protocols":[]}"#.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .unsupportedSchemaVersion(99))
    }

    @Test("未対応バージョンのとき、破棄のメソッドは何もしない")
    func discardDoesNothingForUnsupportedSchemaVersion() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-discard-version-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = #"{"schemaVersion":99,"protocols":[]}"#
        try Data(original.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .unsupportedSchemaVersion(99))

        let discarded = model.discardCorruptedData()

        #expect(discarded == false, "アプリを更新すれば読めるはずのデータを破棄してはいけない")
        #expect(model.loadFailure != nil, "詰みが解除されてはいけない")
        #expect(model.loadFailureKind == .unsupportedSchemaVersion(99))
        let after = try String(contentsOf: url, encoding: .utf8)
        #expect(after == original, "ファイルが書き換えられてはいけない")
    }

    @Test("読み取り不能のとき、破棄のメソッドは何もしない")
    func discardDoesNothingForUnreadableFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-discard-unreadable-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .unreadableFile)

        let discarded = model.discardCorruptedData()

        #expect(discarded == false, "権限・I/O 障害で開けないだけのデータを破棄してはいけない")
        #expect(model.loadFailure != nil, "詰みが解除されてはいけない")
        #expect(model.loadFailureKind == .unreadableFile)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        #expect(isDir.boolValue, "ディレクトリのままであること（上書きされていない）")
    }

    @Test("内容破損のときだけ破棄が働き、その後に登録できる状態になる")
    func discardWorksForCorruptedContentAndAllowsRegistration() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-discard-corrupted-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"protocols":"not-an-array"}"#.utf8).write(to: url)

        let model = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(model.loadFailureKind == .corruptedContent)

        let discarded = model.discardCorruptedData()

        #expect(discarded == true)
        #expect(model.loadFailure == nil, "破棄したら詰みが解除され、保存を再開できなければならない")
        #expect(model.loadFailureKind == nil)
        #expect(model.protocols.isEmpty)

        // 破棄後に登録できる（保存が再開している）ことを確認する
        model.add(sample("破棄後に登録したもの"))
        let reloaded = CustomProtocolStoreModel(store: CustomProtocolStore(fileURL: url))
        #expect(reloaded.protocols.map(\.name) == ["破棄後に登録したもの"])
    }

    @Test("hasStore == false のときは破棄も含めて何も働かない")
    func discardDoesNothingWhenStoreIsNil() throws {
        let model = CustomProtocolStoreModel(store: nil)
        #expect(!model.hasStore)
        #expect(model.loadFailure != nil)

        let discarded = model.discardCorruptedData()

        #expect(discarded == false, "破棄して書き直す保存先がそもそも無い")
        #expect(model.loadFailure != nil, "保存先が無い状態が解除されてはいけない")
        #expect(!model.hasStore)
    }
}
