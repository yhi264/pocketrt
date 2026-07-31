import Foundation

/// 照射スケジュール生成のルール
struct ScheduleRules: Hashable {
    var includeWeekends: Bool       // 土日も照射するか
    var includeHolidays: Bool        // 祝日も照射するか
    var overrideOn: Set<DateKey>     // 強制照射日（休止条件を上書き）
    var overrideOff: Set<DateKey>    // 強制休止日（照射条件を上書き）

    init(
        includeWeekends: Bool = false,
        includeHolidays: Bool = false,
        overrideOn: Set<DateKey> = [],
        overrideOff: Set<DateKey> = []
    ) {
        self.includeWeekends = includeWeekends
        self.includeHolidays = includeHolidays
        self.overrideOn = overrideOn
        self.overrideOff = overrideOff
    }
}

/// 日付の同値比較を年月日のみで行うためのキー
struct DateKey: Hashable, Codable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(from date: Date, calendar: Calendar = .jstGregorian) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 0
        self.month = c.month ?? 0
        self.day = c.day ?? 0
    }

    func date(in calendar: Calendar = .jstGregorian) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return calendar.date(from: c) ?? Date()
    }
}

extension Calendar {
    static var jstGregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        c.locale = Locale(identifier: "ja_JP")
        return c
    }
}

/// スケジュール生成結果
struct ScheduleResult: Hashable {
    let treatmentDays: [Date]        // 照射日（n 件、昇順）
    let startDate: Date
    let endDate: Date                // 最終照射日
    let totalCalendarDays: Int       // start から end までの暦日数（両端含む）
    let restDays: Int                // 期間内の休止日数

    /// 指定日時点で照射済みの分割数
    func fractionsCompleted(by date: Date, calendar: Calendar = .jstGregorian) -> Int {
        let targetKey = DateKey(from: date, calendar: calendar)
        return treatmentDays.filter { DateKey(from: $0, calendar: calendar) <= targetKey }.count
    }
}

extension DateKey: Comparable {
    static func < (lhs: DateKey, rhs: DateKey) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

enum ScheduleCalculator {

    /// 開始日 + ルールから照射日リストを生成する。
    /// 5 年（1825 日）を上限とし、達しない場合は途中で打ち切る。
    static func generate(
        fractions n: Int,
        startDate: Date,
        rules: ScheduleRules,
        holidays: HolidayProvider,
        calendar: Calendar = .jstGregorian
    ) -> ScheduleResult {
        guard n > 0 else {
            return ScheduleResult(treatmentDays: [], startDate: startDate, endDate: startDate,
                                  totalCalendarDays: 0, restDays: 0)
        }

        let startOfStart = calendar.startOfDay(for: startDate)
        var days: [Date] = []
        var cursor = startOfStart
        var iter = 0
        let limit = 365 * 5

        while days.count < n && iter < limit {
            if shouldTreat(on: cursor, rules: rules, holidays: holidays, calendar: calendar) {
                days.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            iter += 1
        }

        let end = days.last ?? startOfStart
        let span = calendar.dateComponents([.day], from: startOfStart, to: end).day ?? 0
        let totalCalendarDays = span + 1
        let rest = totalCalendarDays - days.count

        return ScheduleResult(
            treatmentDays: days,
            startDate: startOfStart,
            endDate: end,
            totalCalendarDays: totalCalendarDays,
            restDays: max(0, rest)
        )
    }

    /// 指定日が照射日かどうか判定する。
    /// 優先順位: overrideOff > overrideOn > 週末/祝日ルール
    static func shouldTreat(
        on date: Date,
        rules: ScheduleRules,
        holidays: HolidayProvider,
        calendar: Calendar = .jstGregorian
    ) -> Bool {
        let key = DateKey(from: date, calendar: calendar)
        if rules.overrideOff.contains(key) { return false }
        if rules.overrideOn.contains(key) { return true }

        let weekday = calendar.component(.weekday, from: date)  // 1=日, 7=土
        let isWeekend = (weekday == 1 || weekday == 7)
        if isWeekend && !rules.includeWeekends { return false }

        if holidays.isHoliday(date) && !rules.includeHolidays { return false }

        return true
    }
}
