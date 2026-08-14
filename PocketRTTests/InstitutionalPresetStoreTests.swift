import Testing
import Foundation
@testable import PocketRT

@Suite("自施設プリセットの永続化")
struct InstitutionalPresetStoreTests {

    /// テストごとに使い捨ての URL を返す
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-test-\(UUID().uuidString).json")
    }

    private func sample(name: String = "前立腺癌根治") -> InstitutionalPreset {
        InstitutionalPreset(id: UUID().uuidString, name: name, totalDose: 60.0,
                            fractions: 20, alphaBeta: 1.5, note: "IGRT 併用",
                            createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("保存と読み込みの往復で内容が一致する")
    func roundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = InstitutionalPresetStore(fileURL: url)
        let data = InstitutionalPresetData(
            schemaVersion: InstitutionalPresetStore.currentSchemaVersion,
            presets: [sample()], hiddenBuiltInKeys: ["srt_acoustic_neuroma"])
        try store.save(data)
        let loaded = try store.load()
        #expect(loaded.presets == data.presets)
        #expect(loaded.hiddenBuiltInKeys == ["srt_acoustic_neuroma"])
    }

    @Test("ファイルがなければ空の内容を返す")
    func loadMissingFile() throws {
        let store = InstitutionalPresetStore(fileURL: tempURL())
        let loaded = try store.load()
        #expect(loaded.presets.isEmpty)
        #expect(loaded.hiddenBuiltInKeys.isEmpty)
    }

    @Test("ファイルがあるが解釈できない場合はエラーを返す（空を返して上書きさせない）")
    func throwsOnCorruptedContent() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ これは JSON ではない".utf8).write(to: url)
        #expect(throws: InstitutionalPresetStoreError.corruptedContent) {
            try InstitutionalPresetStore(fileURL: url).load()
        }
    }

    @Test("schemaVersion は正しいが本文が壊れている場合もエラーを返す")
    func throwsOnValidEnvelopeWithBrokenBody() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#.utf8).write(to: url)
        #expect(throws: InstitutionalPresetStoreError.corruptedContent) {
            try InstitutionalPresetStore(fileURL: url).load()
        }
    }

    @Test("schemaVersion キーがない場合もエラーを返す")
    func throwsOnMissingSchemaVersion() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"presets":[],"hiddenBuiltInKeys":[]}"#.utf8).write(to: url)
        #expect(throws: InstitutionalPresetStoreError.corruptedContent) {
            try InstitutionalPresetStore(fileURL: url).load()
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
        #expect(throws: InstitutionalPresetStoreError.unreadableFile) {
            try InstitutionalPresetStore(fileURL: url).load()
        }
    }

    @Test("未知の schemaVersion は読み込まずエラーを返す")
    func rejectsUnknownSchemaVersion() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":99,"presets":[],"hiddenBuiltInKeys":[]}"#.utf8).write(to: url)
        let store = InstitutionalPresetStore(fileURL: url)
        #expect(throws: InstitutionalPresetStoreError.self) { try store.load() }
    }

    @Test("非表示キーが store を作り直しても保持される")
    func hiddenKeysSurviveNewStoreInstance() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try InstitutionalPresetStore(fileURL: url).save(
            InstitutionalPresetData(schemaVersion: 1, presets: [],
                                    hiddenBuiltInKeys: ["palliative_bone_single"]))
        // 別インスタンスで読み直す（アプリ再起動に相当）
        let loaded = try InstitutionalPresetStore(fileURL: url).load()
        #expect(loaded.hiddenBuiltInKeys == ["palliative_bone_single"])
    }

    @Test("regimenLabel は内蔵プリセットと同じ書式")
    func regimenLabelFormat() {
        #expect(sample().regimenLabel == "60 Gy / 20 Fr")
        let fractional = InstitutionalPreset(id: "x", name: "n", totalDose: 40.05,
                                            fractions: 15, alphaBeta: nil, note: nil,
                                            createdAt: Date(timeIntervalSince1970: 0))
        #expect(fractional.regimenLabel == "40.05 Gy / 15 Fr")
    }

    @Test("正常な値の書式は変わらない")
    func regimenLabelFormatUnchangedForNormalValues() {
        let whole = InstitutionalPreset(id: "x", name: "n", totalDose: 60.0,
                                        fractions: 20, alphaBeta: nil, note: nil,
                                        createdAt: Date(timeIntervalSince1970: 0))
        #expect(whole.regimenLabel == "60 Gy / 20 Fr")
        let fractional = InstitutionalPreset(id: "x", name: "n", totalDose: 52.5,
                                             fractions: 20, alphaBeta: nil, note: nil,
                                             createdAt: Date(timeIntervalSince1970: 0))
        #expect(fractional.regimenLabel == "52.50 Gy / 20 Fr")
    }

    @Test("regimenLabel は範囲外の巨大な値でもクラッシュせず文字列を返す")
    func regimenLabelDoesNotCrashOnOutOfRangeValues() {
        let huge = InstitutionalPreset(id: "x", name: "n", totalDose: 1e100,
                                       fractions: 20, alphaBeta: nil, note: nil,
                                       createdAt: Date(timeIntervalSince1970: 0))
        #expect(huge.regimenLabel == String(format: "%.2f", 1e100) + " Gy / 20 Fr")

        let max = InstitutionalPreset(id: "x", name: "n", totalDose: .greatestFiniteMagnitude,
                                      fractions: 20, alphaBeta: nil, note: nil,
                                      createdAt: Date(timeIntervalSince1970: 0))
        #expect(max.regimenLabel == String(format: "%.2f", Double.greatestFiniteMagnitude) + " Gy / 20 Fr")
    }

    private func tempStore2() -> InstitutionalPresetStore {
        InstitutionalPresetStore(fileURL: tempURL())
    }

    @Test("書き出しと読み込みの往復で内容が一致する")
    func exportImportRoundTrip() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        let p = sample(name: "自施設 A")
        model.add(p)
        model.setHidden(true, key: "palliative_bone_single")

        let exported = model.exportData()
        #expect(exported != nil)

        // 別の空の store に読み込む
        let store2 = tempStore2()
        defer { try? FileManager.default.removeItem(at: store2.fileURL) }
        let model2 = PresetStoreModel(store: store2)
        let result = model2.importData(exported!)
        #expect(result == .success(added: 1, updated: 0))
        #expect(model2.presets.map(\.name) == ["自施設 A"])
        #expect(model2.hiddenBuiltInKeys.contains("palliative_bone_single"))
    }

    @Test("読み込みは既存を消さず、id 一致は上書きする")
    func importMergesWithoutDeleting() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        let keep = sample(name: "残るもの")
        let target = sample(name: "上書き前")
        model.add(keep)
        model.add(target)

        var updated = target
        updated.name = "上書き後"
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [updated], hiddenBuiltInKeys: []))

        let result = model.importData(payload)
        #expect(result == .success(added: 0, updated: 1))
        #expect(model.presets.count == 2, "既存が消えてはいけない")
        #expect(model.presets.contains { $0.name == "残るもの" })
        #expect(model.presets.contains { $0.name == "上書き後" })
    }

    @Test("読み込みは壊れた保存ファイルからの復旧手段になる")
    func importRecoversFromCorruptedStore() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        // 外側は正しいが本文が壊れているファイル
        try Data(#"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#.utf8)
            .write(to: store.fileURL)

        let model = PresetStoreModel(store: store)
        #expect(model.loadFailure != nil, "読めなかったことを保持していなければならない")

        // 書き出しておいたファイルの内容
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [sample(name: "復旧したもの")],
            hiddenBuiltInKeys: ["srt_acoustic_neuroma"]))

        #expect(model.importData(payload) == .replaced(count: 1))
        #expect(model.loadFailure == nil, "復旧したら保存を再開できなければならない")
        #expect(model.presets.map(\.name) == ["復旧したもの"])

        // 実際に保存されていること（別インスタンスで読み直す）
        let reloaded = PresetStoreModel(store: InstitutionalPresetStore(fileURL: store.fileURL))
        #expect(reloaded.loadFailure == nil)
        #expect(reloaded.presets.map(\.name) == ["復旧したもの"])
        #expect(reloaded.hiddenBuiltInKeys.contains("srt_acoustic_neuroma"))
    }

    @Test("未知の schemaVersion は読み込まない")
    func importRejectsUnknownVersion() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample(name: "既存"))
        let payload = Data(#"{"schemaVersion":99,"presets":[],"hiddenBuiltInKeys":[]}"#.utf8)
        #expect(model.importData(payload) == .unsupportedVersion(99))
        #expect(model.presets.count == 1, "失敗しても既存を壊さない")
    }

    @Test("壊れた JSON は読み込まない")
    func importRejectsCorrupted() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample(name: "既存"))
        #expect(model.importData(Data("壊れている".utf8)) == .invalidFormat)
        #expect(model.presets.count == 1)
    }

    @Test("詰み状態で不正なファイルを読み込んでも、置き換えも解除もされない")
    func importOfInvalidFileDoesNotRecoverOrDestroy() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let broken = #"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#
        try Data(broken.utf8).write(to: store.fileURL)

        let model = PresetStoreModel(store: store)
        #expect(model.loadFailure != nil)

        // 未知のバージョン
        #expect(model.importData(Data(#"{"schemaVersion":99,"presets":[],"hiddenBuiltInKeys":[]}"#.utf8))
                == .unsupportedVersion(99))
        #expect(model.loadFailure != nil, "不正な読み込みで詰みを解除してはいけない")

        // 壊れた JSON
        #expect(model.importData(Data("壊れている".utf8)) == .invalidFormat)
        #expect(model.loadFailure != nil, "不正な読み込みで詰みを解除してはいけない")

        // 元のファイルが上書きされていないこと
        #expect(try String(contentsOf: store.fileURL, encoding: .utf8) == broken)
    }

    @Test("範囲外の総線量（1e100）を持つファイルは 1 件も取り込まない")
    func importRejectsOutOfRangeDose() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample(name: "既存"))

        let malicious = InstitutionalPreset(id: "malicious", name: "壊れた値", totalDose: 1e100,
                                            fractions: 20, alphaBeta: nil, note: nil,
                                            createdAt: Date(timeIntervalSince1970: 0))
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [malicious], hiddenBuiltInKeys: []))

        guard case .invalidPresetValues(let names) = model.importData(payload) else {
            Issue.record("不正値の case になっていない")
            return
        }
        #expect(names == ["壊れた値"])
        #expect(model.presets.map(\.name) == ["既存"], "1 件でも不正なら既存は変わらない")
    }

    @Test("範囲外の総線量（Double.greatestFiniteMagnitude）を持つファイルは取り込まない")
    func importRejectsGreatestFiniteMagnitudeDose() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample(name: "既存"))

        let malicious = InstitutionalPreset(id: "malicious", name: "壊れた値", totalDose: .greatestFiniteMagnitude,
                                            fractions: 20, alphaBeta: nil, note: nil,
                                            createdAt: Date(timeIntervalSince1970: 0))
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [malicious], hiddenBuiltInKeys: []))

        #expect(model.importData(payload) == .invalidPresetValues(names: ["壊れた値"]))
        #expect(model.presets.map(\.name) == ["既存"])
    }

    @Test("複数件のうち 1 件でも不正なら、正常な分も含めて何も取り込まない")
    func importRejectsWholeFileWhenOneEntryIsInvalid() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        let model = PresetStoreModel(store: store)
        model.add(sample(name: "既存"))

        let ok = sample(name: "正常な値")
        let bad = InstitutionalPreset(id: "malicious", name: "壊れた値", totalDose: 1e100,
                                      fractions: 20, alphaBeta: nil, note: nil,
                                      createdAt: Date(timeIntervalSince1970: 0))
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [ok, bad], hiddenBuiltInKeys: []))

        #expect(model.importData(payload) == .invalidPresetValues(names: ["壊れた値"]))
        #expect(model.presets.map(\.name) == ["既存"], "正常なプリセットも巻き込んで何も取り込まない")
    }

    @Test("詰み状態からの復旧経路でも範囲外の値は弾く")
    func importRecoveryPathRejectsOutOfRangeDose() throws {
        let store = tempStore2()
        defer { try? FileManager.default.removeItem(at: store.fileURL) }
        // 外側は正しいが本文が壊れているファイル
        try Data(#"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#.utf8)
            .write(to: store.fileURL)

        let model = PresetStoreModel(store: store)
        #expect(model.loadFailure != nil)

        let malicious = InstitutionalPreset(id: "malicious", name: "壊れた値", totalDose: 1e100,
                                            fractions: 20, alphaBeta: nil, note: nil,
                                            createdAt: Date(timeIntervalSince1970: 0))
        let payload = try JSONEncoder().encode(InstitutionalPresetData(
            schemaVersion: 1, presets: [malicious], hiddenBuiltInKeys: []))

        #expect(model.importData(payload) == .invalidPresetValues(names: ["壊れた値"]),
                "壊れた状態から不正な値を持つファイルで「復旧」できてはいけない")
        #expect(model.loadFailure != nil, "不正な読み込みで詰みを解除してはいけない")
        #expect(model.presets.isEmpty)
    }
}
