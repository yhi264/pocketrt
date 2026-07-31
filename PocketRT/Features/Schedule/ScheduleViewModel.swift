import Foundation

@Observable
final class ScheduleViewModel {
    /// 「今日」を返すクロージャ。テストで固定日を注入するために外から差し替えられる。
    @ObservationIgnored private let clock: () -> Date

    init(clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
        self.startDate = Calendar.jstGregorian.startOfDay(for: clock())
    }

    var totalDoseText: String = "60"
    var fractionsText: String = "30"
    var startDate: Date
    var includeWeekends: Bool = false
    var includeHolidays: Bool = false
    var overrideOn: Set<DateKey> = []
    var overrideOff: Set<DateKey> = []

    let holidays: HolidayProvider = JapaneseHolidaysProvider.shared

    var totalDose: Double? { Double(totalDoseText) }
    var fractions: Int? { Int(fractionsText) }
    var dosePerFraction: Double? {
        guard let D = totalDose, let n = fractions, n > 0 else { return nil }
        return D / Double(n)
    }

    var totalDoseError: String? {
        guard let v = totalDose else { return totalDoseText.isEmpty ? nil : "数値を入力" }
        return (0.1...200).contains(v) ? nil : "0.1〜200 Gy"
    }
    var fractionsError: String? {
        guard let v = fractions else { return fractionsText.isEmpty ? nil : "整数を入力" }
        return (1...99).contains(v) ? nil : "1〜99 Fr"
    }

    var isValid: Bool {
        totalDoseError == nil && fractionsError == nil && totalDose != nil && fractions != nil
    }

    private var rules: ScheduleRules {
        ScheduleRules(
            includeWeekends: includeWeekends,
            includeHolidays: includeHolidays,
            overrideOn: overrideOn,
            overrideOff: overrideOff
        )
    }

    var schedule: ScheduleResult? {
        guard let n = fractions, isValid else { return nil }
        return ScheduleCalculator.generate(
            fractions: n, startDate: startDate, rules: rules, holidays: holidays
        )
    }

    var todayCompletedFractions: Int {
        schedule?.fractionsCompleted(by: clock()) ?? 0
    }
    var todayCompletedDose: Double? {
        guard let d = dosePerFraction else { return nil }
        return Double(todayCompletedFractions) * d
    }
    var progressFraction: Double? {
        guard let n = fractions, n > 0 else { return nil }
        return Double(todayCompletedFractions) / Double(n)
    }

    /// 今日を含む直近 14 日のスケジュールエントリ
    func upcomingEntries(maxCount: Int = 14) -> [ScheduleEntry] {
        guard maxCount > 0 else { return [] }
        guard let schedule else { return [] }
        let cal = Calendar.jstGregorian
        let today = cal.startOfDay(for: clock())
        var start = today
        // 開始日が今日より先なら、開始日から
        if cal.startOfDay(for: schedule.startDate) > today {
            start = cal.startOfDay(for: schedule.startDate)
        }
        var entries: [ScheduleEntry] = []
        var cursor = start
        let treatmentSet = Set(schedule.treatmentDays.map { DateKey(from: $0, calendar: cal) })

        for _ in 0..<maxCount {
            let key = DateKey(from: cursor, calendar: cal)
            let isTreat = treatmentSet.contains(key)
            let fr = schedule.fractionsCompleted(by: cursor, calendar: cal)
            let reason = restReason(date: cursor)
            entries.append(ScheduleEntry(
                date: cursor,
                isTreatment: isTreat,
                fractionNumber: isTreat ? fr : nil,
                restReason: isTreat ? nil : reason
            ))
            // 期間終了したら break
            if cal.startOfDay(for: cursor) >= cal.startOfDay(for: schedule.endDate) && entries.count >= 7 {
                break
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return entries
    }

    private func restReason(date: Date) -> String {
        let cal = Calendar.jstGregorian
        let key = DateKey(from: date, calendar: cal)
        if overrideOff.contains(key) { return "個別休止" }
        if let name = holidays.holidayName(date), !includeHolidays { return name }
        let wd = cal.component(.weekday, from: date)
        if (wd == 1 || wd == 7) && !includeWeekends { return wd == 1 ? "日曜" : "土曜" }
        return "—"
    }

    func apply(preset: FractionationPreset) {
        totalDoseText = preset.totalDose == preset.totalDose.rounded()
            ? "\(Int(preset.totalDose))"
            : String(format: "%.2f", preset.totalDose)
        fractionsText = "\(preset.fractions)"
    }

    func addOverrideOn(_ date: Date) {
        overrideOn.insert(DateKey(from: date))
    }
    func addOverrideOff(_ date: Date) {
        overrideOff.insert(DateKey(from: date))
    }
    func removeOverrideOn(_ key: DateKey) {
        overrideOn.remove(key)
    }
    func removeOverrideOff(_ key: DateKey) {
        overrideOff.remove(key)
    }
}

struct ScheduleEntry: Identifiable {
    var id: Date { date }
    let date: Date
    let isTreatment: Bool
    let fractionNumber: Int?
    let restReason: String?
}
