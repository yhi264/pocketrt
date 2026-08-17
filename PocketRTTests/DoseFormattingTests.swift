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

    // MARK: - plainString
    //
    // 検証エラーに出す許容範囲の上下限のように、小数点以下の桁数を前提にできない値に使う。
    // doseString / alphaBetaString と違い桁数を固定しない。

    @Test("plainString は整数に見える値を整数表記にする")
    func plainStringFormatsIntegers() {
        #expect(DoseFormat.plainString(20.0) == "20")
        #expect(DoseFormat.plainString(200.0) == "200")
        #expect(DoseFormat.plainString(0.0) == "0")
        #expect(DoseFormat.plainString(-5.0) == "-5")
    }

    @Test("plainString は小数を桁数を固定せずに表す")
    func plainStringFormatsDecimals() {
        #expect(DoseFormat.plainString(0.1) == "0.1")
        #expect(DoseFormat.plainString(4.5) == "4.5")
    }

    @Test("plainString は Int に収まらない巨大な値でもクラッシュしない")
    func plainStringDoesNotCrashOnHugeValue() {
        // この関数を作った理由そのもの。素の Int(Double) は変換できない値でトラップする。
        #expect(!DoseFormat.plainString(1e100).isEmpty)
        #expect(!DoseFormat.plainString(.greatestFiniteMagnitude).isEmpty)
        #expect(!DoseFormat.plainString(-1e100).isEmpty)
    }

    @Test("plainString は非有限値でもクラッシュしない")
    func plainStringDoesNotCrashOnNonFinite() {
        #expect(!DoseFormat.plainString(.infinity).isEmpty)
        #expect(!DoseFormat.plainString(-.infinity).isEmpty)
        #expect(!DoseFormat.plainString(.nan).isEmpty)
    }
}
