import Testing
import Foundation
@testable import PocketRT

@Suite("自施設プリセットの保持")
struct PresetStoreModelTests {

    private func tempStore() -> InstitutionalPresetStore {
        InstitutionalPresetStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-model-\(UUID().uuidString).json"))
    }

    private func sample(_ name: String) -> InstitutionalPreset {
        InstitutionalPreset(id: UUID().uuidString, name: name, totalDose: 60,
                            fractions: 20, alphaBeta: nil, note: nil,
                            createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("追加した内容が保存され、読み直せる")
    func addPersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample("自施設 A"))
        // 別インスタンスで読み直す
        let reloaded = PresetStoreModel(store: store)
        #expect(reloaded.presets.map(\.name) == ["自施設 A"])
    }

    @Test("削除した内容が保存される")
    func deletePersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        let p = sample("自施設 A")
        model.add(p)
        model.delete(id: p.id)
        #expect(PresetStoreModel(store: store).presets.isEmpty)
    }

    @Test("非表示にした内蔵プリセットが一覧から消え、設定が保存される")
    func hidingBuiltInPersists() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.setHidden(true, key: "srt_acoustic_neuroma")
        #expect(!model.visibleBuiltIns(category: .srt).contains { $0.id == "srt_acoustic_neuroma" })
        let reloaded = PresetStoreModel(store: store)
        #expect(reloaded.hiddenBuiltInKeys.contains("srt_acoustic_neuroma"))
        #expect(!reloaded.visibleBuiltIns(category: .srt).contains { $0.id == "srt_acoustic_neuroma" })
    }

    @Test("非表示を戻すと一覧に復帰する")
    func unhidingRestores() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.setHidden(true, key: "srt_acoustic_neuroma")
        model.setHidden(false, key: "srt_acoustic_neuroma")
        #expect(model.visibleBuiltIns(category: .srt).contains { $0.id == "srt_acoustic_neuroma" })
    }

    @Test("読み込みに失敗した場合は保存せず、既存のファイルを壊さない")
    func doesNotOverwriteWhenLoadFailed() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-broken-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // 外側は正しいが本文が壊れているファイル。部分書き込みや手動編集で起こる。
        let broken = #"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#
        try Data(broken.utf8).write(to: url)

        let model = PresetStoreModel(store: InstitutionalPresetStore(fileURL: url))
        #expect(model.loadFailure != nil, "読めなかったことを利用者に伝えられなければならない")

        // この状態で編集しても、元のファイルを上書きしない
        model.add(InstitutionalPreset(id: "x", name: "追加", totalDose: 60, fractions: 20,
                                      alphaBeta: nil, note: nil, createdAt: Date(timeIntervalSince1970: 0)))
        let after = try String(contentsOf: url, encoding: .utf8)
        #expect(after == broken, "読めなかっただけの登録を上書きで消してはいけない")
    }

    @Test("ファイルが存在するのに読めない場合も loadFailure が立ち、保存を止める")
    func unreadableFileSetsLoadFailure() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-unreadable-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // fileURL の位置にディレクトリを作ると、fileExists は true を返すが
        // Data(contentsOf:) は失敗する。
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let model = PresetStoreModel(store: InstitutionalPresetStore(fileURL: url))
        #expect(model.loadFailure != nil, "開けなかったことを利用者に伝えられなければならない")
        #expect(model.presets.isEmpty)

        // この状態で編集しても保存が走らない（ディレクトリのままであること）
        model.add(InstitutionalPreset(id: "x", name: "追加", totalDose: 60, fractions: 20,
                                      alphaBeta: nil, note: nil, createdAt: Date(timeIntervalSince1970: 0)))
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        #expect(isDir.boolValue, "persist() が働いてディレクトリを上書きしてはいけない")
    }

    @Test("store が nil（保存先が決まらない）場合も loadFailure が立ち、保存しない")
    func nilStoreSetsLoadFailure() throws {
        let model = PresetStoreModel(store: nil)
        #expect(model.loadFailure != nil, "保存先が決まらなかったことを利用者に伝えられなければならない")
        #expect(model.presets.isEmpty)

        // persist() が何もしないこと（クラッシュしない、状態が変わらないことで確認する）
        model.add(InstitutionalPreset(id: "x", name: "追加", totalDose: 60, fractions: 20,
                                      alphaBeta: nil, note: nil, createdAt: Date(timeIntervalSince1970: 0)))
        #expect(model.loadFailure != nil)
    }

    @Test("store が nil のとき、読み込んでも「保存先が無い」状態は解除されない")
    func importDoesNotClearNilStoreState() throws {
        let model = PresetStoreModel(store: nil)
        #expect(model.loadFailure != nil)
        #expect(!model.hasStore)

        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
            presets: [InstitutionalPreset(id: "x", name: "復旧を試みる値", totalDose: 60,
                                          fractions: 20, alphaBeta: nil, note: nil,
                                          createdAt: Date(timeIntervalSince1970: 0))],
            hiddenBuiltInKeys: []))

        // 戻り値が「成功」や「置き換えた」を表さないこと。保存先が無いので
        // 読み込んでも何も保存できず、それを「復旧した」と見せてはならない。
        #expect(model.importData(payload) == .storeUnavailable)
        if case .failure(.storeUnavailable) = model.previewImport(payload) {
            // 期待どおり
        } else {
            Issue.record("previewImport は storeUnavailable を返さなければならない")
        }

        // 状態が変わっていないこと（loadFailure が解除されていない、presets が空のまま）
        #expect(model.loadFailure != nil, "保存先が無い状態が読み込みで解除されてはいけない")
        #expect(model.presets.isEmpty, "保存先が無いので取り込まれてはいけない")
        #expect(!model.hasStore)
    }

    @Test("store が nil のとき、applyImport を直接呼んでも storeUnavailable を返し何もしない")
    func applyImportDoesNothingWhenStoreIsNil() throws {
        let model = PresetStoreModel(store: nil)
        let decoded = InstitutionalPresetData(
            schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
            presets: [InstitutionalPreset(id: "x", name: "復旧を試みる値", totalDose: 60,
                                          fractions: 20, alphaBeta: nil, note: nil,
                                          createdAt: Date(timeIntervalSince1970: 0))],
            hiddenBuiltInKeys: [])
        #expect(model.applyImport(decoded) == .storeUnavailable)
        #expect(model.loadFailure != nil)
        #expect(model.presets.isEmpty)
    }

    @Test("非表示にしていない内蔵プリセットは全件見える")
    func nothingHiddenByDefault() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        let total = PresetCategory.allCases.reduce(0) { $0 + model.visibleBuiltIns(category: $1).count }
        #expect(total == 18)
    }
}
