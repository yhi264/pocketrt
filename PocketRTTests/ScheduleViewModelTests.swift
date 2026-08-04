import Testing
import Foundation
@testable import PocketRT

@Suite("ScheduleViewModel.upcomingEntries")
struct ScheduleViewModelUpcomingEntriesTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateKey(year: y, month: m, day: d).date(in: .jstGregorian)
    }

    /// 開始日 2026-08-03（月）、10 Fr、平日のみ照射の ViewModel を作る。
    /// today で「今日」を固定する。
    private func makeVM(today: Date) -> ScheduleViewModel {
        let vm = ScheduleViewModel(clock: { today })
        vm.totalDoseText = "30"
        vm.fractionsText = "10"
        vm.startDate = date(2026, 8, 3)
        vm.includeWeekends = false
        vm.includeHolidays = false
        return vm
    }

    @Test("初日が今日なら先頭エントリは Fr 1")
    func firstDayIsFractionOne() {
        let vm = makeVM(today: date(2026, 8, 3))
        let entries = vm.upcomingEntries()
        #expect(entries.first?.isTreatment == true)
        #expect(entries.first?.fractionNumber == 1)
        #expect(DateKey(from: entries.first!.date) == DateKey(year: 2026, month: 8, day: 3))
    }

    @Test("3 回目の照射日が今日なら先頭エントリは Fr 3（off-by-one 回帰）")
    func thirdDayIsFractionThree() {
        let vm = makeVM(today: date(2026, 8, 5))
        let entries = vm.upcomingEntries()
        #expect(entries.first?.fractionNumber == 3)
    }

    @Test("土日は休止として理由が付く")
    func weekendsAreRest() {
        let vm = makeVM(today: date(2026, 8, 3))
        let entries = vm.upcomingEntries()
        // index 5 = 8/8(土), index 6 = 8/9(日)
        #expect(entries[5].isTreatment == false)
        #expect(entries[5].restReason == "土曜")
        #expect(entries[5].fractionNumber == nil)
        #expect(entries[6].isTreatment == false)
        #expect(entries[6].restReason == "日曜")
    }

    @Test("祝日は休止として祝日名が付く")
    func holidayIsRestWithName() {
        let vm = makeVM(today: date(2026, 8, 3))
        let entries = vm.upcomingEntries()
        // index 8 = 8/11(火) 山の日
        #expect(DateKey(from: entries[8].date) == DateKey(year: 2026, month: 8, day: 11))
        #expect(entries[8].isTreatment == false)
        #expect(entries[8].restReason == "山の日")
    }

    @Test("休止日をまたいだ後の Fr 番号がずれない（土日を挟んで 8/10 は Fr 6、祝日を挟んで 8/12 は Fr 7）")
    func fractionNumberIsCorrectAfterRestDays() {
        let vm = makeVM(today: date(2026, 8, 3))
        let entries = vm.upcomingEntries()
        // index 7 = 8/10(月): 8/8(土)・8/9(日)の休止を挟んだ6回目の照射
        #expect(DateKey(from: entries[7].date) == DateKey(year: 2026, month: 8, day: 10))
        #expect(entries[7].isTreatment == true)
        #expect(entries[7].fractionNumber == 6)
        // index 9 = 8/12(水): 8/11(火・山の日)の休止を挟んだ7回目の照射
        #expect(DateKey(from: entries[9].date) == DateKey(year: 2026, month: 8, day: 12))
        #expect(entries[9].isTreatment == true)
        #expect(entries[9].fractionNumber == 7)
    }

    @Test("開始日が未来なら先頭エントリは開始日で Fr 1")
    func futureStartBeginsAtStartDate() {
        let today = date(2026, 8, 3)
        let vm = ScheduleViewModel(clock: { today })
        vm.totalDoseText = "30"
        vm.fractionsText = "10"
        vm.startDate = date(2026, 8, 10)
        vm.includeWeekends = false
        vm.includeHolidays = false
        let entries = vm.upcomingEntries()
        #expect(DateKey(from: entries.first!.date) == DateKey(year: 2026, month: 8, day: 10))
        #expect(entries.first?.fractionNumber == 1)
    }

    @Test("startDate の初期値は注入した clock の日付になる")
    func startDateUsesInjectedClock() {
        let today = date(2026, 8, 5)
        let vm = ScheduleViewModel(clock: { today })
        #expect(DateKey(from: vm.startDate) == DateKey(year: 2026, month: 8, day: 5))
    }

    @Test("祝日データの収録範囲内で終わるスケジュールは警告を出さない")
    func scheduleWithinCoveredYearsHasNoWarning() {
        let vm = makeVM(today: date(2026, 8, 3))
        #expect(vm.schedule != nil)
        #expect(vm.holidayDataWarning == nil)
    }

    @Test("祝日データの収録範囲を超えて終わるスケジュールは警告を出す")
    func scheduleBeyondCoveredYearsHasWarning() {
        let today = date(2030, 12, 1)
        let vm = ScheduleViewModel(clock: { today })
        vm.totalDoseText = "60"
        vm.fractionsText = "30"
        vm.startDate = date(2030, 12, 1)
        vm.includeWeekends = false
        vm.includeHolidays = false
        #expect(vm.schedule != nil)
        #expect(vm.holidayDataWarning != nil)
    }
}
