import Testing
import Foundation
@testable import PocketRT

@Suite("自施設プリセットの入力検証")
struct PresetValidatorTests {

    private func validate(name: String = "前立腺癌根治", dose: String = "60",
                          fx: String = "20", ab: String = "", note: String = "")
        -> Result<InstitutionalPresetDraft, PresetValidationError> {
        PresetValidator.validate(name: name, totalDose: dose, fractions: fx, alphaBeta: ab, note: note)
    }

    @Test("正しい入力は通る")
    func acceptsValidInput() throws {
        let d = try validate().get()
        #expect(d.name == "前立腺癌根治")
        #expect(d.totalDose == 60)
        #expect(d.fractions == 20)
        #expect(d.alphaBeta == nil)
    }

    @Test("α/β は空でよく、その場合は nil")
    func alphaBetaIsOptional() throws {
        #expect(try validate(ab: "").get().alphaBeta == nil)
        #expect(try validate(ab: "1.5").get().alphaBeta == 1.5)
    }

    @Test("名前が空白のみなら弾く")
    func rejectsBlankName() {
        #expect(validate(name: "   ") == .failure(.nameEmpty))
        #expect(validate(name: "") == .failure(.nameEmpty))
    }

    @Test("名前が 40 文字を超えたら弾く")
    func rejectsLongName() {
        #expect(validate(name: String(repeating: "あ", count: 41)) == .failure(.nameTooLong))
        #expect((try? validate(name: String(repeating: "あ", count: 40)).get()) != nil)
    }

    @Test("総線量の範囲外を弾く")
    func rejectsDoseOutOfRange() {
        #expect(validate(dose: "0") == .failure(.totalDoseOutOfRange))
        #expect(validate(dose: "200.1") == .failure(.totalDoseOutOfRange))
        #expect(validate(dose: "abc") == .failure(.totalDoseOutOfRange))
    }

    @Test("無限大と巨大な指数表記を弾く")
    func rejectsNonFinite() {
        #expect(validate(dose: "inf") == .failure(.totalDoseOutOfRange))
        #expect(validate(dose: "1e309") == .failure(.totalDoseOutOfRange))
        #expect(validate(ab: "inf") == .failure(.alphaBetaOutOfRange))
    }

    @Test("分割数の範囲外を弾く")
    func rejectsFractionsOutOfRange() {
        #expect(validate(fx: "0") == .failure(.fractionsOutOfRange))
        #expect(validate(fx: "100") == .failure(.fractionsOutOfRange))
        #expect(validate(fx: "1.5") == .failure(.fractionsOutOfRange))
    }

    @Test("α/β の範囲外を弾く")
    func rejectsAlphaBetaOutOfRange() {
        #expect(validate(ab: "0.4") == .failure(.alphaBetaOutOfRange))
        #expect(validate(ab: "30.1") == .failure(.alphaBetaOutOfRange))
    }

    @Test("読み込みに失敗しているときは編集の導線を出さない")
    func editingDisabledWhenLoadFailed() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocketrt-editor-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"schemaVersion":1,"presets":"not-an-array","hiddenBuiltInKeys":[]}"#.utf8).write(to: url)

        let model = PresetStoreModel(store: InstitutionalPresetStore(fileURL: url))
        #expect(model.loadFailure != nil, "読めなかったことを保持していなければならない")

        // この状態で追加しても保存されない。UI 側で導線を出さないことの根拠になる
        model.add(InstitutionalPreset(id: "x", name: "追加", totalDose: 60, fractions: 20,
                                      alphaBeta: nil, note: nil, createdAt: Date(timeIntervalSince1970: 0)))
        let after = try String(contentsOf: url, encoding: .utf8)
        #expect(after.contains("not-an-array"), "元のファイルを上書きしてはいけない")
    }

    @Test("メモが 100 文字を超えたら弾く")
    func rejectsLongNote() {
        #expect(validate(note: String(repeating: "あ", count: 101)) == .failure(.noteTooLong))
    }

    @Test("境界ちょうどの値は通る")
    func acceptsBoundaryValues() throws {
        // 総線量の下限と上限
        #expect((try? validate(dose: "0.1").get()) != nil)
        #expect((try? validate(dose: "200").get()) != nil)
        // 分割数の下限と上限
        #expect((try? validate(fx: "1").get()) != nil)
        #expect((try? validate(fx: "99").get()) != nil)
        // α/β の下限と上限
        #expect(try validate(ab: "0.5").get().alphaBeta == 0.5)
        #expect(try validate(ab: "30").get().alphaBeta == 30)
        // メモの上限
        #expect((try? validate(note: String(repeating: "あ", count: 100)).get()) != nil)
    }

    @Test("前後の空白は落とす")
    func trimsWhitespace() throws {
        #expect(try validate(name: "  前立腺  ").get().name == "前立腺")
    }

    // MARK: - 数値版（取り込み時の検証に使う）

    @Test("数値版: 正しい入力は通る")
    func numericAcceptsValidInput() throws {
        let d = try PresetValidator.validate(name: "前立腺癌根治", totalDose: 60, fractions: 20,
                                             alphaBeta: 1.5, note: "IGRT 併用").get()
        #expect(d.name == "前立腺癌根治")
        #expect(d.totalDose == 60)
        #expect(d.fractions == 20)
        #expect(d.alphaBeta == 1.5)
        #expect(d.note == "IGRT 併用")
    }

    @Test("数値版: 範囲外の巨大な総線量（1e100）を弾く")
    func numericRejectsHugeDose() {
        let result = PresetValidator.validate(name: "n", totalDose: 1e100, fractions: 20,
                                               alphaBeta: nil, note: nil)
        #expect(result == .failure(.totalDoseOutOfRange))
    }

    @Test("数値版: 範囲外の総線量（Double.greatestFiniteMagnitude）を弾く")
    func numericRejectsGreatestFiniteMagnitudeDose() {
        let result = PresetValidator.validate(name: "n", totalDose: .greatestFiniteMagnitude,
                                               fractions: 20, alphaBeta: nil, note: nil)
        #expect(result == .failure(.totalDoseOutOfRange))
    }

    @Test("数値版: 無限大の総線量を弾く")
    func numericRejectsInfiniteDose() {
        let result = PresetValidator.validate(name: "n", totalDose: .infinity, fractions: 20,
                                               alphaBeta: nil, note: nil)
        #expect(result == .failure(.totalDoseOutOfRange))
    }

    @Test("数値版: 範囲外の分割数を弾く")
    func numericRejectsFractionsOutOfRange() {
        #expect(PresetValidator.validate(name: "n", totalDose: 60, fractions: 0,
                                         alphaBeta: nil, note: nil) == .failure(.fractionsOutOfRange))
        #expect(PresetValidator.validate(name: "n", totalDose: 60, fractions: 100,
                                         alphaBeta: nil, note: nil) == .failure(.fractionsOutOfRange))
    }

    @Test("数値版: 範囲外の α/β を弾く")
    func numericRejectsAlphaBetaOutOfRange() {
        #expect(PresetValidator.validate(name: "n", totalDose: 60, fractions: 20,
                                         alphaBeta: 1e100, note: nil) == .failure(.alphaBetaOutOfRange))
    }

    @Test("数値版: α/β が nil なら範囲検証をしない")
    func numericAllowsNilAlphaBeta() throws {
        let d = try PresetValidator.validate(name: "n", totalDose: 60, fractions: 20,
                                             alphaBeta: nil, note: nil).get()
        #expect(d.alphaBeta == nil)
    }
}
