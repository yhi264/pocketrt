import Testing
import Foundation
@testable import PocketRT

/// 自施設の判定基準の書き出しと読み込み。
///
/// D1（プリセット）の取り込みテストと同じ観点に加え、**D2 固有の危険**
/// ——データが無事なまま読めていない状態で読み込ませないこと——を厚く見る。
@Suite("自施設の判定基準の書き出しと読み込み")
struct CustomProtocolImportTests {

    private func tempStore() -> CustomProtocolStore {
        CustomProtocolStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-custom-protocol-import-\(UUID().uuidString).json"))
    }

    private func sample(_ name: String, id: String = UUID().uuidString,
                        within: Double = 4.5) -> CustomProtocol {
        CustomProtocol(id: id, name: name, note: nil,
                       thresholds: [.r50: MetricThreshold(within: within, tolerated: nil)],
                       createdAt: Date(timeIntervalSince1970: 0))
    }

    /// 任意の JSON を組み立てる。`CustomProtocolData` を通すので、
    /// 保存ファイルと同じ形式になる。
    private func json(_ protocols: [CustomProtocol], schemaVersion: Int? = nil) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = CustomProtocolData(
            schemaVersion: schemaVersion ?? CustomProtocolStore.currentSchemaVersion,
            protocols: protocols)
        return try! encoder.encode(data)
    }

    // MARK: - 往復

    @Test("書き出したものを読み込むと同じ内容に戻る")
    func roundTrip() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("肺 SBRT 当院基準"))
        model.add(sample("脊椎 SBRT 当院基準", within: 3.0))
        let exported = try #require(model.exportData())

        // 別の空の store に読み込む
        let other = tempStore()
        defer { try? FileManager.default.removeItem(at: other.fileURL) }
        let fresh = CustomProtocolStoreModel(store: other)
        #expect(fresh.importData(exported) == .success(added: 2, updated: 0))
        #expect(Set(fresh.protocols.map(\.name)) == ["肺 SBRT 当院基準", "脊椎 SBRT 当院基準"])
    }

    @Test("書き出した内容は保存ファイルとして読み直せる")
    func exportIsAValidStoreFile() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("当院基準"))
        let exported = try #require(model.exportData())

        // 書き出したものをそのまま保存ファイルとして置く。バックアップから
        // 手で戻す経路が成立していなければ、書き出す意味が薄い。
        let restored = tempStore()
        defer { try? FileManager.default.removeItem(at: restored.fileURL) }
        try exported.write(to: restored.fileURL)
        #expect(try restored.load().protocols.map(\.name) == ["当院基準"])
    }

    // MARK: - 合流

    @Test("既存は消えず、id が一致するものだけ上書きされる")
    func mergesWithoutLosingExisting() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("残るもの", id: "keep"))
        model.add(sample("上書きされるもの", id: "overwrite", within: 4.5))

        let incoming = json([sample("上書き後", id: "overwrite", within: 6.0),
                             sample("新規", id: "new")])
        #expect(model.importData(incoming) == .success(added: 1, updated: 1))

        #expect(model.protocols.count == 3)
        #expect(model.protocols.first { $0.id == "keep" }?.name == "残るもの")
        #expect(model.protocols.first { $0.id == "overwrite" }?.name == "上書き後")
        #expect(model.protocols.first { $0.id == "overwrite" }?.thresholds[.r50]?.within == 6.0)
    }

    // MARK: - 検証（この機能の核心）

    @Test("範囲外の値を含むファイルは 1 件も取り込まない")
    func rejectsOutOfRangeValues() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("既存"))

        // R50% の範囲は 0.1〜20.0
        let bad = json([sample("正常", within: 4.5), sample("範囲外", within: 1e9)])
        #expect(model.importData(bad) == .invalidProtocolValues(names: ["範囲外"]))
        // 1 件でも不正なら何も入らない。部分的に入ると、何が入って何が
        // 入らなかったかを利用者が確認できない。
        #expect(model.protocols.map(\.name) == ["既存"])
    }

    @Test("無限大を含むファイルを取り込まない")
    func rejectsInfinity() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        // JSON は Infinity を表現できないので、範囲外の巨大値で代替する。
        // 検証は isFinite と範囲の両方を見ている。
        let bad = json([sample("巨大", within: Double.greatestFiniteMagnitude)])
        #expect(model.importData(bad) == .invalidProtocolValues(names: ["巨大"]))
        #expect(model.protocols.isEmpty)
    }

    @Test("tolerated が within 以下のファイルを取り込まない")
    func rejectsInvertedThreshold() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        let inverted = CustomProtocol(
            id: "x", name: "逆転", note: nil,
            thresholds: [.r50: MetricThreshold(within: 5.0, tolerated: 3.0)],
            createdAt: Date(timeIntervalSince1970: 0))
        #expect(model.importData(json([inverted])) == .invalidProtocolValues(names: ["逆転"]))
        #expect(model.protocols.isEmpty)
    }

    @Test("名前が空の基準は「（名前なし）」として報告される")
    func reportsEmptyNamePlaceholder() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        #expect(model.importData(json([sample("")])) == .invalidProtocolValues(names: ["（名前なし）"]))
    }

    @Test("形式が壊れたファイルを取り込まない")
    func rejectsInvalidFormat() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        #expect(model.importData(Data("これは JSON ではない".utf8)) == .invalidFormat)
    }

    @Test("未対応の schemaVersion を取り込まない")
    func rejectsUnsupportedVersion() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        #expect(model.importData(json([sample("将来")], schemaVersion: 99)) == .unsupportedVersion(99))
        #expect(model.protocols.isEmpty)
    }

    // MARK: - 失敗状態ごとの出し分け（D2 固有）

    @Test("保存先が無いとき、書き出しも読み込みもできない")
    func storeUnavailable() throws {
        let model = CustomProtocolStoreModel(store: nil)
        #expect(!model.canExport)
        #expect(!model.canImport)
        #expect(model.exportData() == nil)
        #expect(model.importData(json([sample("復旧")])) == .storeUnavailable)
        #expect(model.loadFailure != nil, "読み込んでも「保存先が無い」状態は解除されない")
    }

    @Test("corruptedContent は読み込みで復旧できる（破棄より失うものが少ない）")
    func recoversFromCorruptedContent() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        try Data("{ 壊れている".utf8).write(to: store.fileURL)
        let model = CustomProtocolStoreModel(store: store)
        #expect(model.loadFailureKind == .corruptedContent)
        #expect(model.canImport, "破棄しか手段が無い状態にしてはならない")
        #expect(!model.canExport, "空の内容を書き出させない")

        #expect(model.importData(json([sample("戻した基準")])) == .replaced(count: 1))
        #expect(model.loadFailure == nil)
        #expect(model.loadFailureKind == nil)
        // 保存が再開していること
        #expect(CustomProtocolStoreModel(store: store).protocols.map(\.name) == ["戻した基準"])
    }

    @Test("unreadableFile では読み込ませない（データは無事なので置き換えると失う）")
    func blocksImportWhenFileIsMerelyUnreadable() throws {
        let store = tempStore()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.fileURL.path)
            try? FileManager.default.removeItem(at: store.fileURL)
        }
        // 正常な内容を置いてから、読み出せなくする
        try json([sample("無事な登録")]).write(to: store.fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: store.fileURL.path)

        let model = CustomProtocolStoreModel(store: store)
        try #require(model.loadFailureKind == .unreadableFile)
        #expect(!model.canImport, "置き換えると、読めるようになったはずの登録を失う")
        #expect(!model.canExport)
        #expect(model.importData(json([sample("別の内容")]))
                == .blockedByIntactData(.unreadableFile))

        // 元のファイルが上書きされていないこと（ここが本題）
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.fileURL.path)
        #expect(try store.load().protocols.map(\.name) == ["無事な登録"])
    }

    @Test("unsupportedSchemaVersion では読み込ませない（アプリ更新で読めるデータを守る）")
    func blocksImportWhenSchemaIsNewer() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        try json([sample("将来の形式の登録")], schemaVersion: 99).write(to: store.fileURL)

        let model = CustomProtocolStoreModel(store: store)
        try #require(model.loadFailureKind == .unsupportedSchemaVersion(99))
        #expect(!model.canImport)
        #expect(model.importData(json([sample("別の内容")]))
                == .blockedByIntactData(.unsupportedSchemaVersion(99)))

        // ファイルが上書きされていないこと
        let raw = try Data(contentsOf: store.fileURL)
        struct Probe: Decodable { let schemaVersion: Int }
        #expect(try JSONDecoder().decode(Probe.self, from: raw).schemaVersion == 99)
    }

    // MARK: - 確認を挟む経路

    @Test("previewImport は状態を変えない")
    func previewDoesNotMutate() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = CustomProtocolStoreModel(store: store)
        model.add(sample("既存"))

        let preview = model.previewImport(json([sample("新規")]))
        guard case .success(let p) = preview else {
            Issue.record("検証を通るはず"); return
        }
        #expect(p.willReplace == false)
        #expect(p.data.protocols.map(\.name) == ["新規"])
        #expect(model.protocols.map(\.name) == ["既存"], "確認前に状態が変わってはならない")

        #expect(model.applyImport(p.data) == .success(added: 1, updated: 0))
        #expect(Set(model.protocols.map(\.name)) == ["既存", "新規"])
    }

    @Test("corruptedContent では previewImport が willReplace を立てる")
    func previewSignalsReplacement() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        try Data("{ 壊れている".utf8).write(to: store.fileURL)
        let model = CustomProtocolStoreModel(store: store)

        guard case .success(let p) = model.previewImport(json([sample("戻す")])) else {
            Issue.record("検証を通るはず"); return
        }
        #expect(p.willReplace, "確認ダイアログで「置き換える」と伝えられなければならない")
    }

    // MARK: - 保存ファイル自体の検証

    @Test("範囲外の値を含む保存ファイルは corruptedContent として扱う")
    func storeRejectsOutOfRangeOnLoad() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        try json([sample("範囲外", within: 1e9)]).write(to: store.fileURL)

        let model = CustomProtocolStoreModel(store: store)
        #expect(model.loadFailureKind == .corruptedContent)
        #expect(model.protocols.isEmpty)
        #expect(model.canImport, "復旧経路は残す")
    }
}
