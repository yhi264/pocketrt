import Testing
import Foundation
import CoreTransferable
import UniformTypeIdentifiers
@testable import PocketRT

/// 書き出したファイルを自分で読み込めることを、content type の水準で守る。
///
/// `.fileImporter(allowedContentTypes: [.json])` は content type で絞り込む。
/// 書き出し側が JSON を名乗らなければ、書き出したファイルは読み込みの一覧に
/// 現れず、書き出しと読み込みが片道になる。UI テストでは捉えにくいので
/// ここで固定する。
@Suite("書き出すファイルの content type")
struct ExportContentTypeTests {

    /// `exportedContentTypes()` は iOS 18.2 以降。アプリの最低対応 OS は
    /// それより古いが、テストは実行中のシミュレータの OS で動く。取得できない
    /// 環境では検査を飛ばす（アプリ側の挙動は OS に依らない）。
    @Test("自施設基準の書き出しは JSON を名乗る")
    @available(iOS 18.2, *)
    func customProtocolExportIsJSON() {
        let types = CustomProtocolExportFile.exportedContentTypes()
        #expect(types.contains { $0.conforms(to: .json) },
                "実際の型: \(types.map(\.identifier))")
    }

    @Test("プリセットの書き出しは JSON を名乗る")
    @available(iOS 18.2, *)
    func presetExportIsJSON() {
        let types = InstitutionalPresetExportFile.exportedContentTypes()
        #expect(types.contains { $0.conforms(to: .json) },
                "実際の型: \(types.map(\.identifier))")
    }

    /// D1・D2 がかつて使っていた `ShareLink(item: Data)` が壊れていたことの裏取り。
    /// `Data` が JSON を名乗らないなら、D1 の書き出しは読み込みの一覧に
    /// 現れない。
    @Test("素の Data は JSON を名乗らない")
    @available(iOS 18.2, *)
    func rawDataIsNotJSON() {
        let types = Data.exportedContentTypes()
        #expect(!types.contains { $0.conforms(to: .json) },
                "実際の型: \(types.map(\.identifier))")
    }
}
