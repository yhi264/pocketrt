import Testing
import Foundation
@testable import PocketRT

@Suite("線量・α/β の表示整形")
struct DoseFormattingTests {

    @Test("doseString は整数に見える値を整数表記、それ以外を小数第 2 位で表す")
    func doseStringFormat() {
        #expect(DoseFormat.doseString(60.0) == "60")
        #expect(DoseFormat.doseString(52.5) == "52.50")
        #expect(DoseFormat.doseString(40.05) == "40.05")
    }

    @Test("alphaBetaString は整数に見える値を整数表記、それ以外を小数第 1 位で表す")
    func alphaBetaStringFormat() {
        #expect(DoseFormat.alphaBetaString(10.0) == "10")
        #expect(DoseFormat.alphaBetaString(1.5) == "1.5")
        #expect(DoseFormat.alphaBetaString(3.0) == "3")
    }

    @Test("alphaBetaString は範囲外の巨大な値（1e100）でもクラッシュせず文字列を返す")
    func alphaBetaStringDoesNotCrashOnHugeValue() {
        #expect(DoseFormat.alphaBetaString(1e100) == String(format: "%.1f", 1e100))
    }

    @Test("alphaBetaString は範囲外の値（Double.greatestFiniteMagnitude）でもクラッシュせず文字列を返す")
    func alphaBetaStringDoesNotCrashOnGreatestFiniteMagnitude() {
        #expect(DoseFormat.alphaBetaString(.greatestFiniteMagnitude)
                == String(format: "%.1f", Double.greatestFiniteMagnitude))
    }

    @Test("alphaBetaString は負の巨大な値でもクラッシュせず文字列を返す")
    func alphaBetaStringDoesNotCrashOnHugeNegativeValue() {
        #expect(DoseFormat.alphaBetaString(-1e100) == String(format: "%.1f", -1e100))
    }

    @Test("doseString は範囲外の巨大な値でもクラッシュせず文字列を返す")
    func doseStringDoesNotCrashOnHugeValue() {
        #expect(DoseFormat.doseString(1e100) == String(format: "%.2f", 1e100))
        #expect(DoseFormat.doseString(.greatestFiniteMagnitude)
                == String(format: "%.2f", Double.greatestFiniteMagnitude))
    }
}
