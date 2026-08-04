import SwiftUI

struct TreatmentCalendarView: View {
    let schedule: ScheduleResult
    let holidays: HolidayProvider
    let includeHolidays: Bool
    let overrideOff: Set<DateKey>
    let today: Date
    var monthCount: Int = 3

    private let calendar = Calendar.jstGregorian
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var treatmentKeys: [DateKey: Int] {
        var map: [DateKey: Int] = [:]
        for (i, d) in schedule.treatmentDays.enumerated() {
            map[DateKey(from: d, calendar: calendar)] = i + 1
        }
        return map
    }

    private var grids: [MonthGrid] {
        ScheduleCalculator.monthGrids(
            from: schedule.startDate, monthCount: monthCount, calendar: calendar)
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            weekdayHeader

            ForEach(grids) { grid in
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthFormatter.string(from: grid.firstDay))
                        .font(.subheadline.bold())
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                            Color.clear.frame(height: 34)
                        }
                        ForEach(1...grid.dayCount, id: \.self) { day in
                            if let date = calendar.date(byAdding: .day, value: day - 1, to: grid.firstDay) {
                                dayCell(date)
                            }
                        }
                    }
                }
            }

            legend

            if schedule.endDate > lastDisplayedDay {
                Text("治療期間は表示範囲（\(monthCount) ヶ月）を超えています。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastDisplayedDay: Date {
        guard let last = grids.last,
              let end = calendar.date(byAdding: .day, value: last.dayCount - 1, to: last.firstDay)
        else { return schedule.startDate }
        return end
    }

    private var weekdaySymbols: [String] {
        DateFormatter().shortWeekdaySymbols
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, symbol in
                Text(symbol)
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(i == 0 ? .red : (i == 6 ? .blue : .secondary))
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let key = DateKey(from: date, calendar: calendar)
        let frNumber = treatmentKeys[key]
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let inPeriod = date >= calendar.startOfDay(for: schedule.startDate)
            && date <= calendar.startOfDay(for: schedule.endDate)

        VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption2)
            if let frNumber {
                Text("\(frNumber)")
                    .font(.caption2.bold())
            } else {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor(date: date, key: key, isTreatment: frNumber != nil, inPeriod: inPeriod))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isToday ? Color.accentColor : .clear, lineWidth: 2)
        )
        .foregroundStyle(inPeriod ? .primary : .tertiary)
    }

    private func backgroundColor(date: Date, key: DateKey, isTreatment: Bool, inPeriod: Bool) -> Color {
        if isTreatment { return .green.opacity(0.25) }
        guard inPeriod else { return .clear }
        if overrideOff.contains(key) { return .red.opacity(0.15) }
        if holidays.holidayName(date) != nil && !includeHolidays { return .orange.opacity(0.15) }
        let wd = calendar.component(.weekday, from: date)
        if wd == 1 || wd == 7 { return Color(.systemGray5) }
        return .clear
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(.green.opacity(0.25), "照射日")
            legendItem(Color(.systemGray5), "土日")
            legendItem(.orange.opacity(0.15), "祝日")
            legendItem(.red.opacity(0.15), "個別休止")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }
}
