import Testing
import Foundation
@testable import PocketRT

@Suite("ScheduleCalculator.monthGrids")
struct MonthGridTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.jstGregorian.date(from: c)!
    }

    @Test("開始日の月から指定した月数ぶん返す")
    func returnsRequestedMonthCount() {
        let grids = ScheduleCalculator.monthGrids(from: date(2026, 8, 3), monthCount: 3)
        #expect(grids.count == 3)
        let cal = Calendar.jstGregorian
        #expect(cal.component(.month, from: grids[0].firstDay) == 8)
        #expect(cal.component(.month, from: grids[1].firstDay) == 9)
        #expect(cal.component(.month, from: grids[2].firstDay) == 10)
    }

    @Test("開始日が月の途中でも月初から始まる")
    func startsAtFirstOfMonth() {
        let grids = ScheduleCalculator.monthGrids(from: date(2026, 8, 27), monthCount: 1)
        let cal = Calendar.jstGregorian
        #expect(cal.component(.day, from: grids[0].firstDay) == 1)
        #expect(cal.component(.month, from: grids[0].firstDay) == 8)
    }

    @Test("2026年8月は土曜始まり → leadingBlanks = 6、31日")
    func august2026() {
        let g = ScheduleCalculator.monthGrids(from: date(2026, 8, 1), monthCount: 1)[0]
        #expect(g.leadingBlanks == 6)
        #expect(g.dayCount == 31)
    }

    @Test("2026年9月は火曜始まり → leadingBlanks = 2、30日")
    func september2026() {
        let g = ScheduleCalculator.monthGrids(from: date(2026, 9, 1), monthCount: 1)[0]
        #expect(g.leadingBlanks == 2)
        #expect(g.dayCount == 30)
    }

    @Test("2026年10月は木曜始まり → leadingBlanks = 4、31日")
    func october2026() {
        let g = ScheduleCalculator.monthGrids(from: date(2026, 10, 1), monthCount: 1)[0]
        #expect(g.leadingBlanks == 4)
        #expect(g.dayCount == 31)
    }

    @Test("うるう年の2月は29日、平年は28日")
    func february() {
        let leap = ScheduleCalculator.monthGrids(from: date(2028, 2, 1), monthCount: 1)[0]
        #expect(leap.dayCount == 29)
        let common = ScheduleCalculator.monthGrids(from: date(2026, 2, 1), monthCount: 1)[0]
        #expect(common.dayCount == 28)
    }

    @Test("年をまたいでも連続する")
    func crossesYearBoundary() {
        let grids = ScheduleCalculator.monthGrids(from: date(2026, 12, 15), monthCount: 3)
        let cal = Calendar.jstGregorian
        #expect(grids.count == 3)
        #expect(cal.component(.year, from: grids[0].firstDay) == 2026)
        #expect(cal.component(.month, from: grids[0].firstDay) == 12)
        #expect(cal.component(.year, from: grids[2].firstDay) == 2027)
        #expect(cal.component(.month, from: grids[2].firstDay) == 2)
    }

    @Test("monthCount が 0 以下なら空を返す")
    func nonPositiveMonthCount() {
        #expect(ScheduleCalculator.monthGrids(from: date(2026, 8, 1), monthCount: 0).isEmpty)
        #expect(ScheduleCalculator.monthGrids(from: date(2026, 8, 1), monthCount: -1).isEmpty)
    }
}

@Suite("ScheduleCalculator.monthCount")
struct MonthCountDerivationTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.jstGregorian.date(from: c)!
    }

    @Test("1ヶ月に収まるコースは月数1")
    func withinOneMonth() {
        let count = ScheduleCalculator.monthCount(from: date(2026, 8, 3), to: date(2026, 8, 11))
        #expect(count == 1)
    }

    @Test("月末に始まり翌月にまたがるコースは月数2")
    func spansTwoMonths() {
        let count = ScheduleCalculator.monthCount(from: date(2026, 8, 27), to: date(2026, 9, 5))
        #expect(count == 2)
    }

    @Test("3ヶ月以上にまたがるコースは3にクランプされる")
    func clampedToThree() {
        let count = ScheduleCalculator.monthCount(from: date(2026, 8, 3), to: date(2027, 1, 15))
        #expect(count == 3)
    }
}
